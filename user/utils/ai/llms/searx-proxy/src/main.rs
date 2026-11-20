use base64::Engine;
use std::env;
use std::io::Read;
use std::net::IpAddr;
use std::time::Duration;
use tiny_http::{Header, Method, Response, Server};

fn main() {
    let bind = env::var("BIND").unwrap_or_else(|_| "0.0.0.0:8889".into());
    let upstream = env::var("UPSTREAM").unwrap_or_else(|_| "https://search.tsiru.pet".into());
    let firecrawl_host_ip = env::var("FIRECRAWL_HOST_IP")
        .ok()
        .and_then(|ip| ip.parse::<IpAddr>().ok());
    let user = env::var("BASIC_USER").expect("BASIC_USER must be set");
    let pass = env::var("BASIC_PASS").expect("BASIC_PASS must be set");

    let token = base64::engine::general_purpose::STANDARD.encode(format!("{user}:{pass}"));
    let auth = format!("Basic {token}");
    let client = ureq::AgentBuilder::new()
        .timeout(Duration::from_secs(12))
        .redirects(0)
        .build();

    let server = Server::http(&bind).expect("failed to bind");
    eprintln!("searx-proxy listening on {bind} -> {upstream}");

    for mut request in server.incoming_requests() {
        // Rootless Docker's outbound connections to the host LAN address
        // originate from that same host address.
        if !request
            .remote_addr()
            .is_some_and(|addr| addr.ip().is_loopback() || Some(addr.ip()) == firecrawl_host_ip)
        {
            let _ = request.respond(Response::empty(403));
            continue;
        }

        let path = request.url().to_string();
        if path.split('?').next() != Some("/search") {
            let _ = request.respond(Response::empty(404));
            continue;
        }

        let method = match request.method() {
            Method::Get => "GET",
            Method::Post => "POST",
            _ => {
                let _ = request.respond(Response::empty(405));
                continue;
            }
        };

        let mut body = String::new();
        if method == "POST"
            && request
                .as_reader()
                .take(64 * 1024 + 1)
                .read_to_string(&mut body)
                .is_err()
        {
            let _ = request.respond(Response::empty(400));
            continue;
        }
        if body.len() > 64 * 1024 {
            let _ = request.respond(Response::empty(413));
            continue;
        }

        // Client headers are deliberately NOT forwarded: relaying Accept /
        // User-Agent through to Caddy triggered empty 200 responses (content
        // negotiation weirdness). Auth + identity encoding is all that's
        // needed; SearXNG's /search takes its parameters from the query/body.
        let preq = client
            .request(method, &format!("{upstream}{path}"))
            .set("Authorization", &auth)
            .set("Accept-Encoding", "identity");

        let resp = if body.is_empty() {
            preq.call()
        } else {
            preq.set("Content-Type", "application/x-www-form-urlencoded")
                .send_string(&body)
        };

        let response = match resp {
            Ok(r) | Err(ureq::Error::Status(_, r)) => {
                let status = r.status();
                let ct = r
                    .header("content-type")
                    .map(|v| v.to_string())
                    .unwrap_or_else(|| "application/json".into());
                let mut body_bytes = Vec::new();
                if let Err(e) = r.into_reader().read_to_end(&mut body_bytes) {
                    eprintln!("upstream read error: {e}");
                    let _ = request.respond(Response::empty(502));
                    continue;
                }
                Response::from_data(body_bytes)
                    .with_status_code(status)
                    .with_header(Header::from_bytes(&b"Content-Type"[..], ct.as_bytes()).unwrap())
            }
            Err(e) => {
                eprintln!("upstream error: {e}");
                Response::from_data(b"{\"error\":\"upstream failed\"}".to_vec())
                    .with_status_code(502)
                    .with_header(
                        Header::from_bytes(&b"Content-Type"[..], &b"application/json"[..]).unwrap(),
                    )
            }
        };

        let _ = request.respond(response);
    }
}
