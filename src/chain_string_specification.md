## xml-chains string specification

`/ ` - Tokens separator 

`/ node_tag / `- single token, by default it is assumed as a tag field of the node
`/ A / B / C /` - gives nodes, which can be reached by following the path of nodes with tags `"A"` => `"B"` => `"C"`

`/ node_tag.field_name = c /`- `field_name` is the name of the node field, e.g. `/A.value = ABC/` searches for
a node with tag  `"A"` and with field `"value"` which is equal to `"ABC"`, by default the value is 
parsed as string, by if it can be parsed as a number  e.g. `/ node_tag.field_name = 25.4 /` means that `field_name` field value
of node tagged as `node_tag` is `25.4`  (Float64). Additionally `::text` annotation can be added if we need to parse as a string
`/ node_tag.field_name = 25.4::text /` searches for `field_name`  value `"25.4"` (String) 

`/ node_tag.field_name(key)  /` - searches for special key in field_name, e.g. `/A.attributes(par)/ ` searches for 
node with tag `"A"` which has field attributes, which contains `"par"` key, `/A.attributes(1::text)/ ` searches for
`"1""` as a string. 

`/ node_tag.field_name(key=value)  /` - searches for special key in field_name

`[]`  - block returns true if ANY of emraced patterns are matched, e.g. `/[A,B]/` - searches for nodes with tags `"A"` or `"B"`
any block can be used also in arguments key-values or keys match e.g. `/A.attributes([a,b])` will search for node
with tag `"A"`, which has the field `attributes` with keys `"a"` or `"b"`, `/A.attributes([a = 1::text ,b = f])` is the 
same as in previous example, but seraches for any key-value pairs matches. It is also possible to use braces for many possible field values, e.g. `/A.attributes = [a , b ]/`

`{}`  - block returns true if ALL of emraced patterns are matched, e.g. `/A.attributes({"a","b"})` will search for node
with tag `"A"`, which has the field `attributes` with both keys `"a"` and `"b"`, `/A.attributes({a = 1,b = f})` is the 
same as in previous example, but seraches for all key-value pairs matches

`*` is symbol of any value of tag, e.g. `/*.field_name = "c"/`  - searches for node with any tag and 
`field_name` value `"c"`, e.g. `/*.tag = "A"/` is the same as `/A/`. The `*` can also be used for partial 
matching e.g. `/*Prop/` will search for nodes with tags containing `"Prop"` e.g. `"BulkProp"`, `"PropertyOne"` etc.
Fildnames cannot contain `*` , `/ node_tag.*partial_name = "c" /` is not supported, but `/ node_tag.field_name = "*ca" /` 
is ok.