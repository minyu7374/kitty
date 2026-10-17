local M = { name = "herdr", protocol_version = "3.0.0" }
local request, resize_ratio

function M.detect()
  local pane = vim.env.HERDR_PANE_ID
  local bin = vim.env.HERDR_BIN_PATH or "herdr"
  return pane ~= nil and pane ~= "" and vim.fn.executable(bin) == 1
end

function M.move(direction)
  local result = request({ "pane", "focus", "--direction", direction })
  if not result then
    return false
  end
  if result.focus.changed then
    return true
  end
  if result.focus.reason == "no_neighbor" and vim.env.KITTY_LISTEN_ON then
    local runtime_dir = vim.env.XDG_RUNTIME_DIR or vim.fn.fnamemodify(vim.fn.stdpath("cache"), ":h")
    local context = vim.fn.readfile(runtime_dir .. "/smart-splits-herdr-kitty")
    vim.env.KITTY_LISTEN_ON, vim.env.KITTY_WINDOW_ID = context[1], context[2]
    return require("smart-splits-backend-kitty").move(direction)
  end
  return false
end

function M.health()
  if not M.detect() then
    vim.health.info("Herdr is not active, or its executable is unavailable")
    return
  end
  if request({ "pane", "layout" }) then
    vim.health.ok("Herdr pane is reachable; navigation and cell-based resizing are available")
  else
    vim.health.error("Herdr pane is unreachable; check HERDR_PANE_ID and HERDR_SOCKET_PATH")
  end
end

function M.resize(direction, opts)
  local amount = (opts or {}).amount or 3
  if amount <= 0 then
    return false
  end
  local result = request({ "pane", "layout" })
  if not result or type(result.layout) ~= "table" then
    return false
  end
  local ratio = resize_ratio(result.layout, direction, amount)
  if not ratio then
    return false
  end
  result = request({ "pane", "resize", "--direction", direction, "--amount", tostring(ratio) })
  return result ~= nil and result.resize.changed == true
end

-- Herdr accepts a change in the parent split's ratio; v3 supplies terminal cells.
-- Pick the nearest split on the requested side, then the opposite side, as Herdr does.
resize_ratio = function(layout, direction, amount)
  local horizontal = direction == "left" or direction == "right"
  local before = direction == "left" or direction == "up"
  local axis, size = horizontal and "x" or "y", horizontal and "width" or "height"
  local cross, cross_size = horizontal and "y" or "x", horizontal and "height" or "width"
  local pane
  for _, candidate in ipairs(layout.panes or {}) do
    if candidate.pane_id == vim.env.HERDR_PANE_ID then
      pane = candidate.rect
      break
    end
  end
  if not pane then
    return nil
  end
  -- Layout pane rectangles exclude borders and gaps. Recover the raw leaf
  -- rectangle from split geometry before comparing its edges with Herdr's.
  local cx, cy = pane.x + pane.width / 2, pane.y + pane.height / 2
  local raw = vim.deepcopy(layout.area)
  local right, bottom = raw.x + raw.width, raw.y + raw.height
  for _, split in ipairs(layout.splits or {}) do
    local rect = split.rect
    if cx >= rect.x and cx < rect.x + rect.width and cy >= rect.y and cy < rect.y + rect.height then
      if split.direction == "right" then
        local border = rect.x + math.floor(rect.width * split.ratio + 0.5)
        if cx < border then
          right = math.min(right, border)
        else
          raw.x = math.max(raw.x, border)
        end
      elseif split.direction == "down" then
        local border = rect.y + math.floor(rect.height * split.ratio + 0.5)
        if cy < border then
          bottom = math.min(bottom, border)
        else
          raw.y = math.max(raw.y, border)
        end
      end
    end
  end
  raw.width, raw.height = right - raw.x, bottom - raw.y
  pane = raw
  for _, start_side in ipairs({ before, not before }) do
    local target = pane[axis] + (start_side and 0 or pane[size])
    local best, distance
    for _, split in ipairs(layout.splits or {}) do
      local rect = split.rect
      if
        split.direction == (horizontal and "right" or "down")
        and rect[size] > 0
        and rect[cross] < pane[cross] + pane[cross_size]
        and pane[cross] < rect[cross] + rect[cross_size]
      then
        local border = rect[axis] + math.floor(rect[size] * split.ratio + 0.5)
        local delta = math.abs(border - target)
        if delta <= 2 and (not distance or delta < distance) then
          best, distance = rect[size], delta
        end
      end
    end
    if best then
      return math.min(amount / best, 0.5)
    end
  end
end

request = function(args)
  local command = { vim.env.HERDR_BIN_PATH or "herdr" }
  vim.list_extend(command, args)
  vim.list_extend(command, { "--pane", vim.env.HERDR_PANE_ID })
  local ok, decoded = pcall(function()
    local result = vim.system(command, { text = true, timeout = 500 }):wait()
    if result.code == 0 then
      return vim.json.decode(result.stdout)
    end
  end)
  if ok and type(decoded) == "table" and type(decoded.result) == "table" then
    return decoded.result
  end
end

return M
