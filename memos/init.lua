local action = require 'memos.action'
local config = require 'memos.config'
local meta = require 'memos.meta'

local M = {}

function M.meta()
  return {
    icon = '󰎞',
    desc = 'Memos note client',
    color = 'yellow',
  }
end

local function memo_entry(memo)
  local content = memo.content or ''
  local display_parts = {}

  if memo.createTime then
    local success, parsed = pcall(deck.time.parse, memo.createTime)
    if success then
      memo.timestamp = parsed
      table.insert(display_parts, deck.time.format(memo.timestamp, 'compact'):fg 'yellow')
      table.insert(display_parts, ' ')
    end
  end

  local display_title = content:utf8_sub(1, 60)
  if #content > 60 then display_title = display_title .. '...' end
  table.insert(display_parts, display_title:fg 'green')

  return {
    key = tostring(memo.id),
    kind = 'memo',
    memo = memo,
    display = deck.style.line(display_parts),
  }
end

function M.setup(opt)
  config.setup(opt or {})
  action.setup(config.get())
  meta.setup(config.get())
end

function M.list(_, cb)
  deck.log('info', 'Loading memos list')
  deck.api.set_preview(nil, 'Loading memos...')

  if not action.ready() then
    cb(meta.attach {
      {
        key = 'configure',
        kind = 'info',
        title = 'memos',
        message = 'Configure memos token and base_url first',
        detail = 'Set them in setup() before using this plugin.',
        color = 'yellow',
      },
    })
    return
  end

  action.api_call('GET', '/memos?state=NORMAL&pageSize=100', nil, function(res)
    if not res.success then
      deck.notify('Error: ' .. tostring(res.error or 'Unknown error'))
      cb(meta.attach {})
      return
    end

    local memos = deck.json.decode(res.body)
    if type(memos) ~= 'table' or type(memos.memos) ~= 'table' or #memos.memos == 0 then
      deck.notify 'No memos found'
      cb(meta.attach {})
      return
    end

    local entries = {}
    for _, memo in ipairs(memos.memos) do
      memo.id = memo.name and memo.name:sub(7) or tostring(memo.id or '')
      table.insert(entries, memo_entry(memo))
    end

    deck.log('info', 'Loaded {} memos entries', #entries)
    cb(meta.attach(entries))
  end)
end

return M
