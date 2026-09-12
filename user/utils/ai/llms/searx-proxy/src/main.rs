use base64::Engine;
use std::env;
use std::io::Read;
use tiny_http::{Header, Method, Response, Server};

fn main() {
    let bind = env::var("BIND").unwrap_or_else(|_| "0.0.0.0:8889".into());
    let upstream = env::var("UPSTREAM").unwrap_or_else(|_| "https://search.tsiru.pet".into());
    let user = env::var("BASIC_USER").expect("BASIC_USER must be set");
    let pass = env::var("BASIC_PASS").expect("BASIC_PASS must be set");

    let token = base64::engine::general_purpose::STANDARD.encode(format!("{user}:{pass}"));
    let auth = format!("Basic {token}");

    let server = Server::http(&bind).expect("failed to bind");
    eprintln!("searx-proxy listening on {bind} -> {upstream}");

    for mut request in server.incoming_requests() {
        let mut body = String::new();
        let _ = request.as_reader().read_to_string(&mut body);
        let path = request.url().to_string();

        // Client headers are deliberately NOT forwarded: relaying Accept /
        // User-Agent through to Caddy triggered empty 200 responses (content
        // negotiation weirdness). Auth + identity encoding is all that's
        // needed; SearXNG's /search takes its parameters from the query/body.
        let preq = ureq::request(
            match request.method() {
                Method::Get => "GET",
                Method::Post => "POST",
                _ => "GET",
            },
            &format!("{upstream}{path}"),
        )
        .set("Authorization", &auth)
        // Relay raw bytes only — no transparent compression on either side.
        .set("Accept-Encoding", "identity");

        let resp = if body.is_empty() {
            preq.call()
        } else {
            preq.send_string(&body)
        };

        let response = match resp {
            Ok(r) => {
                let status = r.status();
                let ct = r
                    .header("content-type")
                    .map(|v| v.to_string())
                    .unwrap_or_else(|| "application/json".into());
                let mut body_bytes = Vec::new();
                if let Err(e) = r.into_reader().read_to_end(&mut body_bytes) {
                    eprintln!("upstream read error: {e}");
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
