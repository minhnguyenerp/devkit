# Use Minh Nguyen DevKit to create a Rust - Axum project

Open [**Minh Nguyen DevKit**](../README.md) terminal, navigate to your project container folder e.g `C:\Data\projects`.

Run this command <code>cargo new hello-rust-axum</code> to create the new project. Change the current directory to `C:\Data\projects\hello-rust-axum`, the type `code .` and press **Enter** to open project in VSCode.

In VSCode modify *Cargo.toml* and *main.rs* files as following:

<h5><strong><code>Cargo.toml</code></strong></h5>

```toml
[package]
name = "hello-rust-axum"
version = "0.1.0"
edition = "2025"

[dependencies]
axum = "0.8"
tokio = { version = "1.44", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1"
```

<h5><strong><code>main.rs</code></strong></h5>

```rust
use axum::{routing::get, Router, Json, serve};
use serde::Serialize;
use std::net::SocketAddr;

#[derive(Serialize)]
struct Message {
    message: String,
}

async fn hello_axum() -> Json<Message> {
    Json(Message {
        message: "Hello, Axum!".to_string(),
    })
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(hello_axum));

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Axum listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    serve(listener, app).await.unwrap();
}
```

Open the VSCode Terminal or DevKit terminal to run program <code>cargo run</code> then open browser http://localhost:3000/

You can build release by <code>cargo build --release</code>
