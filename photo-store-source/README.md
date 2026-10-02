# Ali Photo Store

Event galleries, protected watermarked previews, photographer allowlist, manual payment approval and private original downloads.

Runtime: Cloudflare Workers with D1 DB and private R2 BUCKET bindings. Sign-in uses Sites ChatGPT authentication headers. This is server-backed source and cannot run on GitHub Pages alone. Photos and customer records are never stored in this public repository.

Install dependencies, generate Drizzle migrations, and build using the included scripts. Configure .openai/hosting.json with your Site project ID, d1 DB, r2 BUCKET.
