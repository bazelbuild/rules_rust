use hyper::server::{
    accept::Accept,
    conn::{AddrIncoming, AddrStream},
};
use std::{
    pin::Pin,
    task::{Context, Poll},
};

/// A wrapper for `hyper::server::conn::AddrIncoming` that implements `future::stream::Stream` to be
/// used in tests with tonic servers.
pub struct TcpIncoming {
    inner: AddrIncoming,
}

impl TcpIncoming {
    /// Creates a new TcpIncoming by binding to localhost on port zero, which allow the OS to assign
    /// an open port.
    pub fn bind() -> hyper::Result<TcpIncoming> {
        let addr = "127.0.0.1:0".parse().unwrap();
        let inner = AddrIncoming::bind(&addr)?;
        Ok(TcpIncoming { inner })
    }

    /// Get the uri a client should target to connect to the bound address
    pub fn uri(&self) -> tonic::transport::Uri {
        let addr = self.local_addr();
        // unwrap ok as valid port, and thus, uri is guaranteed by successful bind for construction.
        format!("http://{}:{}", addr.ip(), addr.port())
            .parse()
            .unwrap()
    }

    /// Get the local address bound to this listener.
    #[allow(dead_code)]
    pub fn local_addr(&self) -> std::net::SocketAddr {
        self.inner.local_addr()
    }

    /// Sets if keepalive should be enabled, and if so, for how long
    /// https://docs.rs/hyper/0.13.6/hyper/server/conn/struct.AddrIncoming.html#method.set_keepalive
    #[allow(dead_code)]
    pub fn set_keepalive(&mut self, keepalive: Option<core::time::Duration>) -> &mut Self {
        self.inner.set_keepalive(keepalive);
        self
    }

    /// Sets if nodelay should be enabled for the AddrIncoming or not.
    /// https://docs.rs/hyper/0.13.6/hyper/server/conn/struct.AddrIncoming.html#method.set_nodelay
    #[allow(dead_code)]
    pub fn set_nodelay(&mut self, enabled: bool) -> &mut Self {
        self.inner.set_nodelay(enabled);
        self
    }
}

impl futures::stream::Stream for TcpIncoming {
    type Item = Result<AddrStream, std::io::Error>;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        Pin::new(&mut self.inner).poll_accept(cx)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn non_zero_port() {
        let mut incoming = TcpIncoming::bind().expect("bind failed");
        incoming.set_keepalive(None);
        incoming.set_nodelay(false);

        assert!(incoming.local_addr().is_ipv4());
        assert_eq!(
            incoming.local_addr().ip(),
            "127.0.0.1".parse::<std::net::IpAddr>().unwrap()
        );
        // We don't want this to be zero, because a new port should be assigned.
        assert_ne!(incoming.local_addr().port(), 0);

        assert_eq!(incoming.uri().scheme_str().unwrap(), "http");
        assert_eq!(incoming.uri().host().unwrap(), "127.0.0.1");
        assert_eq!(
            incoming.uri().port_u16().unwrap(),
            incoming.local_addr().port()
        );
    }
}
