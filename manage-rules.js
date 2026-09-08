#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const cp = require("child_process");
const M = require("./Model.js");

const FILE_PATH = process.env.WINDOWRULES_LUA || path.join(process.env.HOME, ".config/hypr/windowrules.lua");
const PARSER_LUA = path.join(__dirname, "parser.lua");

const command = process.argv[2] || "read";

if (command === "read") {
  try {
    if (!fs.existsSync(FILE_PATH)) {
      console.log(JSON.stringify({ rules: [], tail: "" }));
      process.exit(0);
    }
    const out = cp.execFileSync("lua", [PARSER_LUA, "read", FILE_PATH], { encoding: "utf8" });
    process.stdout.write(out);
  } catch (err) {
    console.error("Error reading windowrules.lua:", err.message);
    console.log(JSON.stringify({ rules: [], tail: "" }));
  }
} else if (command === "write") {
  let input = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", chunk => { input += chunk; });
  process.stdin.on("end", () => {
    try {
      const data = JSON.parse(input);
      const rules = data.rules || [];
      const tail = data.tail || "";

      // Backup existing file
      if (fs.existsSync(FILE_PATH)) {
        fs.copyFileSync(FILE_PATH, FILE_PATH + ".bak");
      }

      // Format rules
      const lines = [
        "-- Window and Layer Rules converted from oldconfigs/windowrules.conf",
        ""
      ];

      let lastSection = "";
      for (const r of rules) {
        if (r.section && r.section !== lastSection) {
          lines.push("");
          lines.push("-- " + r.section);
          lastSection = r.section;
        }
        let lua = M.ruleToLua(r);
        if (lua) {
          if (r.enabled === false) {
            lines.push("-- " + lua);
          } else {
            lines.push(lua);
          }
        }
      }

      lines.push("");
      if (tail.trim()) {
        lines.push(tail.trim());
        lines.push("");
      }

      const content = lines.join("\n");
      const tmpPath = FILE_PATH + ".tmp." + Date.now();
      fs.writeFileSync(tmpPath, content, "utf8");
      fs.renameSync(tmpPath, FILE_PATH);

      // Invalidate Hyprland Lua cache and reload windowrules.lua live
      try {
        cp.execSync('hyprctl eval \'package.loaded["hypr.windowrules"] = nil; dofile(os.getenv("HOME") .. "/.config/hypr/windowrules.lua")\'', { stdio: "ignore" });
        cp.execSync("hyprctl reload", { stdio: "ignore" });
      } catch (e) {
        // Ignore if hyprctl is temporarily busy
      }

      // Live-sync properties on currently open windows
      try {
        const clientsRaw = cp.execFileSync("hyprctl", ["clients", "-j"], { encoding: "utf8" });
        const clients = JSON.parse(clientsRaw);
        for (const c of clients) {
          for (const r of rules) {
            if (r.enabled === false) continue;
            if (M.matchesClient(c, r.match)) {
              if (r.effects && r.effects.opacity) {
                const parts = String(r.effects.opacity).trim().split(/\s+/);
                const activeVal = parts[0] || "1.0";
                const inactiveVal = parts[1] || activeVal;
                const val = activeVal + " " + inactiveVal;
                const luaCmd = `hl.dsp.window.set_prop({ window = "address:${c.address}", prop = "opacity", value = "${val}" })`;
                try {
                  cp.execFileSync("hyprctl", ["dispatch", luaCmd], { stdio: "ignore" });
                } catch (_) {}
              }
              break;
            }
          }
        }
      } catch (_) {}

      process.stdout.write("OK\n");
    } catch (err) {
      console.error("Error writing windowrules.lua:", err.message);
      process.exit(1);
    }
  });
} else {
  console.error("Unknown command:", command);
  process.exit(1);
}
