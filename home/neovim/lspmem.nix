# :LspMem -- which language servers this nvim spawned, and what they cost.
#
# nvim exposes no public API for a server's pid (it sits on private transport
# fields), but every stdio server is a direct child of the nvim process, so
# /proc has everything needed. Pure lua: no shelling out, so it does not care
# what is on the wrapped PATH.
{ ... }:
{
  programs.nixvim.extraConfigLua = ''
    _M.lspmem = (function()
      local M = {}

      -- Direct children of this nvim process, with their resident memory.
      local function child_processes()
        local self_pid = tostring(vim.uv.os_getpid())
        local out = {}

        local dir = vim.uv.fs_scandir("/proc")
        if not dir then
          return out
        end

        while true do
          local name = vim.uv.fs_scandir_next(dir)
          if not name then
            break
          end

          if name:match("^%d+$") then
            local ok, lines = pcall(vim.fn.readfile, "/proc/" .. name .. "/status")
            if ok then
              local ppid, rss, comm
              for _, line in ipairs(lines) do
                local k, v = line:match("^(%w+):%s*(.+)$")
                if k == "PPid" then
                  ppid = v
                elseif k == "VmRSS" then
                  rss = v
                elseif k == "Name" then
                  comm = v
                end
              end

              if ppid == self_pid then
                local cmdline = ""
                local ok2, raw = pcall(vim.fn.readfile, "/proc/" .. name .. "/cmdline", "b")
                if ok2 and raw[1] then
                  cmdline = raw[1]:gsub("%z", " ")
                end
                table.insert(out, {
                  pid = tonumber(name),
                  comm = comm or "?",
                  cmdline = cmdline,
                  kb = tonumber((rss or ""):match("^(%d+)")) or 0,
                })
              end
            end
          end
        end

        return out
      end

      function M.report()
        local procs = child_processes()

        -- Label each process with the LSP client it backs, matched on the
        -- client's configured command.
        local clients = {}
        for _, c in ipairs(vim.lsp.get_clients()) do
          local cmd = type(c.config.cmd) == "table" and c.config.cmd[1] or nil
          clients[#clients + 1] = {
            name = c.name,
            id = c.id,
            exe = cmd and vim.fs.basename(cmd) or nil,
          }
        end

        table.sort(procs, function(a, b)
          return a.kb > b.kb
        end)

        local lines = {}
        local total = 0
        for _, p in ipairs(procs) do
          local label
          for _, c in ipairs(clients) do
            if c.exe and (p.cmdline:find(c.exe, 1, true) or p.comm == c.exe) then
              label = string.format("%s (id %d)", c.name, c.id)
            end
          end
          total = total + p.kb
          lines[#lines + 1] = string.format(
            "%-28s %-18s pid %-8d %8.1f MB",
            label or "-",
            p.comm,
            p.pid,
            p.kb / 1024
          )
        end

        if #lines == 0 then
          vim.notify("No child processes -- no language servers running.", vim.log.levels.INFO)
          return
        end

        lines[#lines + 1] = string.format("%-56s %8.1f MB total", "", total / 1024)
        vim.api.nvim_echo({ { table.concat(lines, "\n") } }, false, {})
      end

      return M
    end)()

    vim.api.nvim_create_user_command("LspMem", function()
      _M.lspmem.report()
    end, { desc = "Language servers spawned by this nvim, with memory use" })
  '';
}
