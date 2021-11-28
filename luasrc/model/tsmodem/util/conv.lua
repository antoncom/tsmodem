


local code_table = {
  ["0416"] = "Ж",
  ["0443"] = "У",
  ["041A"] = "К"
}

local ucs = "04160443041A"

local char = ""
for i=1, #ucs do
  print(ucs[i])
  --char = string.format("%s%s", char, ucs[i])
  --if (math.fmod(i,4) == 0) then
   -- print(code_table[char])
    --char = ""
  --end
end

local i = 1
local word = ""
for c in string.gmatch(ucs,".") do
  char = char .. c
  if (math.fmod(i,4) == 0) then
    word = word ..code_table[char]
    local ru = "0x" .. char
    print(string.char(tonumber(ru)-848))
    char = ""
  end
  i = i + 1
end
print(word)
