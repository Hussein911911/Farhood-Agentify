import type { NextConfig } from 'next';

// The current app is client-rendered and can be deployed as static assets.
// If server-side Next.js features are added, migrate to a supported adapter.
const nextConfig: NextConfig = { output: 'export', images: { unoptimized: true } };
export default nextConfig;
