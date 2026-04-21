import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import postcss from "./postcss.config.js";

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd(), '');
    const backendTarget = env.BACKEND_PROXY_TARGET || 'http://aiservice-service:80';

    return {
        plugins: [react()],
        css: {
            postcss,
        },
        server: {
            watch: {
                usePolling: true,
            },
            host: true,
            strictPort: true,
            port: 5900,
            allowedHosts: true,
            proxy: {
                '/backend': {
                    target: backendTarget,
                    changeOrigin: true,
                    rewrite: (path: string) => path.replace(/^\/backend/, ''),
                },
                '/api': {
                    target: backendTarget,
                    changeOrigin: true,
                },
            },
        },
    };
});
