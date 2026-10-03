import type { ReactNode } from "react";
import { BottomNav } from "./BottomNav";
import { Header } from "./Header";

type AppShellProps = {
  children: ReactNode;
};

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="min-h-dvh bg-fog text-ink">
      <Header />
      <div className="mx-auto w-full max-w-lg px-4 pb-24 pt-4">{children}</div>
      <BottomNav />
    </div>
  );
}
