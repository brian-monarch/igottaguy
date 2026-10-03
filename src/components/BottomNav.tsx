import { NavLink } from "react-router-dom";

const items = [
  { to: "/", label: "Home", end: true },
  { to: "/add", label: "Add a Guy", end: false },
] as const;

function linkClassName(isActive: boolean): string {
  const tone = isActive ? "text-sage" : "text-ink";
  return `flex min-h-11 min-w-11 flex-1 items-center justify-center rounded-md px-3 text-sm font-medium ${tone} focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sage`;
}

export function BottomNav() {
  return (
    <nav
      aria-label="Primary"
      className="fixed inset-x-0 bottom-0 z-10 border-t border-ink/10 bg-surface px-2 py-1"
    >
      <ul className="mx-auto flex max-w-lg gap-2">
        {items.map((item) => (
          <li key={item.to} className="flex flex-1">
            <NavLink
              to={item.to}
              end={item.end}
              className={({ isActive }) => linkClassName(isActive)}
            >
              {item.label}
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
