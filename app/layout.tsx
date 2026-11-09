import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'Farhood Agentify | لوحة الإدارة', description: 'مساحة إدارة مواقع واشتراكات المطاعم' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="ar" dir="rtl"><body>{children}</body></html>; }
