import { Route, Routes } from "react-router-dom";
import { AppShell } from "./components/AppShell";
import { AddGuyPage } from "./routes/AddGuyPage";
import { HomePage } from "./routes/HomePage";

export function App() {
  return (
    <AppShell>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/add" element={<AddGuyPage />} />
      </Routes>
    </AppShell>
  );
}
