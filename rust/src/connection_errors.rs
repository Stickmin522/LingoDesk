//! Keep actionable handshake diagnostics without exposing tickets, headers, or bodies.
use tungstenite::{
    Error,
    error::{ProtocolError, SubProtocolError, TlsError},
};

pub(super) fn describe(error: &Error) -> String {
    let detail = match error {
        Error::Http(response) => format!("HTTP {}", response.status().as_u16()),
        Error::Tls(TlsError::InvalidDnsName) => "TLS: INVALID_DNS_NAME".into(),
        Error::Tls(error) => if certificate_error(&error.to_string()) {
            "TLS: CERTIFICATE_VALIDATION_FAILED"
        } else {
            "TLS: HANDSHAKE_FAILED"
        }
        .into(),
        Error::Io(error) => {
            // Rustls' lazy handshake can surface certificate errors through io::Error.
            if error.kind() == std::io::ErrorKind::InvalidData
                && certificate_error(&error.to_string())
            {
                "TLS: CERTIFICATE_VALIDATION_FAILED".into()
            } else {
                let kind = match error.kind() {
                    std::io::ErrorKind::TimedOut | std::io::ErrorKind::WouldBlock => "TIMEOUT",
                    std::io::ErrorKind::ConnectionReset | std::io::ErrorKind::ConnectionAborted => {
                        "CONNECTION_RESET"
                    }
                    std::io::ErrorKind::UnexpectedEof | std::io::ErrorKind::BrokenPipe => {
                        "CONNECTION_CLOSED"
                    }
                    std::io::ErrorKind::ConnectionRefused => "CONNECTION_REFUSED",
                    _ => "IO_ERROR",
                };
                format!("NETWORK: {kind}")
            }
        }
        Error::Protocol(error) => {
            let kind = match error {
                ProtocolError::SecWebSocketSubProtocolError(SubProtocolError::NoSubProtocol) => {
                    "MISSING_SUBPROTOCOL"
                }
                ProtocolError::SecWebSocketSubProtocolError(
                    SubProtocolError::InvalidSubProtocol,
                ) => "INVALID_SUBPROTOCOL",
                ProtocolError::SecWebSocketSubProtocolError(
                    SubProtocolError::ServerSentSubProtocolNoneRequested,
                ) => "UNEXPECTED_SUBPROTOCOL",
                ProtocolError::MissingUpgradeWebSocketHeader
                | ProtocolError::MissingConnectionUpgradeHeader => "INVALID_UPGRADE_HEADERS",
                ProtocolError::SecWebSocketAcceptKeyMismatch => "ACCEPT_KEY_MISMATCH",
                _ => "PROTOCOL_ERROR",
            };
            format!("WEBSOCKET: {kind}")
        }
        Error::ConnectionClosed | Error::AlreadyClosed => "NETWORK: CONNECTION_CLOSED".into(),
        _ => "WEBSOCKET: HANDSHAKE_ERROR".into(),
    };
    format!("实时节点握手失败 [{detail}]")
}

fn certificate_error(message: &str) -> bool {
    message.to_ascii_lowercase().contains("certificate")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        net::{TcpListener, TcpStream},
        thread,
        time::Duration,
    };
    use tungstenite::{
        client::IntoClientRequest,
        handshake::server::{Request, Response},
        http,
    };

    fn rejected_handshake(status: Option<u16>, protocol: Option<&'static str>) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let server = thread::spawn(move || {
            let (tcp, _) = listener.accept().unwrap();
            tcp.set_read_timeout(Some(Duration::from_secs(2))).unwrap();
            let result =
                tungstenite::accept_hdr(tcp, |request: &Request, mut response: Response| {
                    assert_eq!(
                        request.headers()["Sec-WebSocket-Protocol"],
                        "lecsync.realtime.v1, PRIVATE_TEST_TICKET"
                    );
                    if let Some(status) = status {
                        return Err(http::Response::builder()
                            .status(status)
                            .header("X-Request-Id", "PRIVATE_TEST_TICKET")
                            .body(Some(
                                "PRIVATE_TEST_TICKET in a rejected response body".to_owned(),
                            ))
                            .unwrap());
                    }
                    if let Some(protocol) = protocol {
                        response
                            .headers_mut()
                            .insert("Sec-WebSocket-Protocol", protocol.parse().unwrap());
                    }
                    Ok(response)
                });
            if status.is_some() {
                assert!(result.is_err());
            }
        });
        let mut request = format!("ws://{address}/v1/sessions/private?token=PRIVATE_TEST_TICKET")
            .into_client_request()
            .unwrap();
        request.headers_mut().insert(
            "Sec-WebSocket-Protocol",
            "lecsync.realtime.v1, PRIVATE_TEST_TICKET".parse().unwrap(),
        );
        let tcp = TcpStream::connect(address).unwrap();
        tcp.set_read_timeout(Some(Duration::from_secs(2))).unwrap();
        let error = match tungstenite::client(request, tcp) {
            Err(tungstenite::HandshakeError::Failure(error)) => error,
            _ => panic!("expected a rejected handshake"),
        };
        server.join().unwrap();
        let message = describe(&error);
        assert!(!message.contains("PRIVATE_TEST_TICKET"));
        assert!(!message.contains("127.0.0.1"));
        message
    }

    #[test]
    fn actual_http_handshake_rejections_retain_status_without_leaking_response_data() {
        for code in [401, 403, 404, 429, 503] {
            assert_eq!(
                rejected_handshake(Some(code), None),
                format!("实时节点握手失败 [HTTP {code}]")
            );
        }
    }

    #[test]
    fn missing_and_invalid_protocol_responses_are_distinguished() {
        assert_eq!(
            rejected_handshake(None, None),
            "实时节点握手失败 [WEBSOCKET: MISSING_SUBPROTOCOL]"
        );
        assert_eq!(
            rejected_handshake(None, Some("wrong-protocol")),
            "实时节点握手失败 [WEBSOCKET: INVALID_SUBPROTOCOL]"
        );
    }

    #[test]
    fn certificate_errors_wrapped_by_io_retain_their_tls_category_without_private_details() {
        let error = Error::Io(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "invalid peer certificate: UnknownIssuer PRIVATE_TEST_TICKET",
        ));
        assert_eq!(
            describe(&error),
            "实时节点握手失败 [TLS: CERTIFICATE_VALIDATION_FAILED]"
        );
        assert_eq!(
            describe(&Error::Tls(TlsError::InvalidDnsName)),
            "实时节点握手失败 [TLS: INVALID_DNS_NAME]"
        );
    }

    #[test]
    fn timeout_and_connection_reset_are_distinguished_without_raw_io_messages() {
        for (kind, code) in [
            (std::io::ErrorKind::TimedOut, "TIMEOUT"),
            (std::io::ErrorKind::ConnectionReset, "CONNECTION_RESET"),
        ] {
            let error = Error::Io(std::io::Error::new(kind, "PRIVATE_TEST_TICKET"));
            assert_eq!(
                describe(&error),
                format!("实时节点握手失败 [NETWORK: {code}]")
            );
        }
    }
}
