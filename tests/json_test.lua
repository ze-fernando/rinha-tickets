local json = require("src.infra.json")

return {
  name = "json",
  tests = {
    {
      name = "codifica objetos em ordem alfabética",
      fn = function(t)
        local encoded = json.encode({
          name = "Chamado",
          count = 3,
          active = true,
          missing = json.null,
        })

        t:equal(encoded, '{"active":true,"count":3,"missing":null,"name":"Chamado"}')
      end,
    },
    {
      name = "decodifica objetos, arrays e nulos",
      fn = function(t)
        local decoded = json.decode('{"items":[1,2,{"ok":true}],"empty":[],"missing":null}')

        t:truthy(json.is_array(decoded.items))
        t:equal(#decoded.items, 3)
        t:equal(decoded.items[3].ok, true)
        t:truthy(json.is_array(decoded.empty))
        t:equal(#decoded.empty, 0)
        t:truthy(json.is_null(decoded.missing))
      end,
    },
    {
      name = "codifica array vazio como lista",
      fn = function(t)
        t:equal(json.encode(json.array({})), "[]")
        t:equal(json.encode({}), "{}")
      end,
    },
    {
      name = "escapa textos especiais",
      fn = function(t)
        t:equal(json.encode({ text = 'linha "um"\nlinha 2' }), '{"text":"linha \\"um\\"\\nlinha 2"}')
      end,
    },
    {
      name = "decodifica escapes unicode",
      fn = function(t)
        local decoded = json.decode('{"text":"A\\u00e7\\u00e3o","emoji":"\\ud83d\\ude00"}')

        t:equal(decoded.text, "Ação")
        t:equal(decoded.emoji, "😀")
      end,
    },
    {
      name = "recusa json inválido",
      fn = function(t)
        t:falsy(pcall(json.decode, "{invalid}"))
        t:falsy(pcall(json.decode, '{"a":1,}'))
        t:falsy(pcall(json.decode, '{"a":1} extra'))
        t:falsy(pcall(json.decode, ""))
      end,
    },
  },
}
