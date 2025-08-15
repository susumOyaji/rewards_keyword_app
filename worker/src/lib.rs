use worker::*;
use serde::Deserialize;
use serde_json;

#[derive(Deserialize, Debug)]
struct UserKeywords {
    #[serde(flatten)]
    keywords: std::collections::HashMap<String, Vec<String>>,
}

fn cors_headers() -> Headers {
    let mut headers = Headers::new();
    headers.set("Access-Control-Allow-Origin", "*").unwrap();
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS, GET").unwrap();
    headers.set("Access-Control-Allow-Headers", "Content-Type").unwrap();
    headers
}

#[event(fetch)]
pub async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    // The panic_hook is enabled in Cargo.toml, no need to set it here.

    let router = Router::new();

    router
        // CORS preflight
        .options("/save", |_, _| {
            Ok(Response::empty().unwrap().with_headers(cors_headers()))
        })
        // Save data API
        .post_async("/save", |mut req, ctx| async move {
            let data: UserKeywords = match req.json().await {
                Ok(json) => json,
                Err(e) => {
                    console_error!("Bad Request: Failed to parse JSON: {}", e);
                    return Response::error(format!("Bad Request: {}", e), 400);
                }
            };

            console_log!("Received data: {:?}", data);

            let kv = ctx.kv("MY_KV")?;

            let json_str = serde_json::to_string(&data.keywords)
                .map_err(|e| worker::Error::RustError(e.to_string()))?;
            kv.put("latest_keywords", json_str)?.execute().await?;

            let mut headers = cors_headers();
            headers.set("Content-Type", "application/json")?;
            
            Ok(Response::from_json(&serde_json::json!({
                "success": true,
                "message": "Data saved to KV successfully."
            }))?.with_headers(headers))
        })
        // Get data API
        .get_async("/get", |_, ctx| async move {
            let kv = ctx.kv("MY_KV")?;
            if let Some(value) = kv.get("latest_keywords").text().await? {
                let mut headers = cors_headers();
                headers.set("Content-Type", "application/json")?;
                Ok(Response::ok(value)?.with_headers(headers))
            } else {
                Response::error("No data found", 404)
            }
        })
        .run(req, env)
        .await
}