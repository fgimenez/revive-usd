import path from 'path'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  turbopack: {
    // Allow imports from outside the frontend/ directory (e.g. ../../deployments/testnet.json)
    root: path.join(__dirname, '..'),
  },
};

export default nextConfig;
