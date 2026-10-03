import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        fog: "#F4F6F4",
        surface: "#FFFFFF",
        ink: "#1E2421",
        sage: "#3B7A57",
        denim: "#4A6FA5",
      },
    },
  },
  plugins: [],
};

export default config;
