import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Ali Photo Store",
  description: "Event photography by Ali. Browse protected previews and order photo packs.",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
