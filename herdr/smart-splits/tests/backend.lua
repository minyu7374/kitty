local root = assert(vim.env.HERDR_BACKEND_DIR)
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(assert(vim.env.SMART_SPLITS_DIR))

local passed = 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    error(name .. ": " .. tostring(err))
  end
  passed = passed + 1
end

local backend = require("smart-splits-backend-herdr")
local real_system = vim.system
local calls, response = {}, { code = 0, stdout = "{}" }
vim.env.HERDR_PANE_ID = "w1:p2"
vim.env.KITTY_LISTEN_ON = nil
vim.env.HERDR_BIN_PATH = vim.v.progpath
vim.system = function(args, opts)
  calls[#calls + 1] = args
  assert(opts.timeout and opts.timeout <= 1000, "CLI call must have a bounded timeout")
  return {
    wait = function()
      return response
    end,
  }
end

test("detection does not spawn a process", function()
  calls = {}
  assert(backend.detect() == true)
  assert(#calls == 0)
  vim.env.HERDR_PANE_ID = nil
  assert(backend.detect() == false)
  vim.env.HERDR_PANE_ID = "w1:p2"
end)

test("moves only report success when Herdr changed focus", function()
  response = { code = 0, stdout = vim.json.encode({ result = { focus = { changed = true } } }) }
  assert(backend.move("left", { at_edge = "stop" }) == true)
  assert(vim.deep_equal(calls[#calls], {
    vim.v.progpath,
    "pane",
    "focus",
    "--direction",
    "left",
    "--pane",
    "w1:p2",
  }))
  response.stdout = vim.json.encode({ result = { focus = { changed = false, reason = "no_neighbor" } } })
  assert(backend.move("left") == false)
end)

test("Herdr edges hand navigation to Kitty without bypassing Herdr neighbors", function()
  local original = package.loaded["smart-splits-backend-kitty"]
  local runtime = vim.env.XDG_RUNTIME_DIR
  local context_dir = vim.fn.tempname()
  vim.fn.mkdir(context_dir)
  vim.env.XDG_RUNTIME_DIR = context_dir
  vim.fn.writefile({ "unix:/tmp/current-kitty", "17" }, context_dir .. "/smart-splits-herdr-kitty")
  local outer_moves, outer_changed = 0, true
  package.loaded["smart-splits-backend-kitty"] = {
    move = function(direction)
      assert(direction == "right")
      assert(vim.env.KITTY_LISTEN_ON == "unix:/tmp/current-kitty", "must use the attaching Kitty's socket")
      assert(vim.env.KITTY_WINDOW_ID == "17")
      outer_moves = outer_moves + 1
      return outer_changed
    end,
  }
  vim.env.KITTY_LISTEN_ON = "unix:/tmp/kitty-test"
  response = { code = 0, stdout = '{"result":{"focus":{"changed":false,"reason":"no_neighbor"}}}' }
  assert(backend.move("right") == true, "Herdr edge must continue into outer Kitty")
  assert(outer_moves == 1)
  outer_changed = false
  assert(backend.move("right") == false, "outer edge must not claim a move")
  response.stdout = '{"result":{"focus":{"changed":true}}}'
  assert(backend.move("right") == true)
  response.stdout = '{"result":{"focus":{"changed":false,"reason":"zoomed"}}}'
  assert(backend.move("right") == false)
  response.code = 1
  assert(backend.move("right") == false)
  assert(outer_moves == 2, "only no_neighbor may hand off to Kitty")
  package.loaded["smart-splits-backend-kitty"] = original
  vim.fn.delete(context_dir, "rf")
  vim.env.XDG_RUNTIME_DIR = runtime
  vim.env.KITTY_LISTEN_ON = nil
end)

test("failed, malformed and timed out CLI responses do not throw or claim a move", function()
  for _, result in ipairs({
    { code = 1, stdout = "{}" },
    { code = 124, stdout = "" },
    { code = 0, stdout = "invalid json" },
    { code = 0, stdout = "null" },
    { code = 0, stdout = '{"result":false}' },
  }) do
    response = result
    assert(backend.move("right") == false)
  end
  local system = vim.system
  vim.system = function()
    error("failed to spawn Herdr")
  end
  assert(backend.move("right") == false)
  vim.system = system
end)

local layout = {
  area = { x = 0, y = 0, width = 200, height = 60 },
  panes = { { pane_id = "w1:p2", rect = { x = 100, y = 0, width = 50, height = 60 } } },
  splits = {
    { direction = "right", ratio = 0.5, rect = { x = 0, y = 0, width = 200, height = 60 } },
    { direction = "right", ratio = 0.5, rect = { x = 100, y = 0, width = 100, height = 60 } },
  },
}

test("resize converts cells using the selected split, including nested layouts", function()
  local real_fake = vim.system
  local amount
  vim.system = function(args, opts)
    assert(opts.timeout)
    if args[2] == "pane" and args[3] == "layout" then
      return {
        wait = function()
          return { code = 0, stdout = vim.json.encode({ result = { layout = layout } }) }
        end,
      }
    end
    assert(args[3] == "resize")
    amount = tonumber(args[7])
    assert(args[8] == "--pane" and args[9] == "w1:p2")
    return {
      wait = function()
        return { code = 0, stdout = '{"result":{"resize":{"changed":true}}}' }
      end,
    }
  end
  assert(backend.resize("right", { amount = 3 }))
  assert(math.abs(amount - 0.03) < 0.000001, "nested split must resize by 3/100")
  assert(backend.resize("left", { amount = 3 }))
  assert(math.abs(amount - 0.015) < 0.000001, "outer split must resize by 3/200")
  layout.panes[1].rect = { x = 104, y = 4, width = 42, height = 52 }
  assert(backend.resize("right", { amount = 3 }), "pane gaps must not hide the raw split boundary")
  assert(math.abs(amount - 0.03) < 0.000001)
  layout.area = { x = 0, y = 0, width = 100, height = 80 }
  layout.panes[1].rect = { x = 1, y = 41, width = 98, height = 38 }
  layout.splits = { { direction = "down", ratio = 0.5, rect = layout.area } }
  assert(backend.resize("up", { amount = 6 }), "vertical resizing must use height")
  assert(math.abs(amount - 0.075) < 0.000001)
  assert(backend.resize("down", { amount = 3 }), "outer edge must use the opposite split")
  assert(math.abs(amount - 0.0375) < 0.000001)
  calls = {}
  assert(backend.resize("right", { amount = 0 }) == false)
  vim.system = real_fake
end)

test("backend conforms to the upstream v3 protocol", function()
  response = { code = 1, stdout = "" }
  for _, result in ipairs(require("smart-splits.protocol_tests").run(backend)) do
    assert(result.ok == true, result.name .. ": " .. tostring(result.ok))
  end
end)

vim.system = real_system
print(("PASS: %d Herdr backend tests"):format(passed))
