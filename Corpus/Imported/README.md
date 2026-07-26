# Imported

Real Shadertoys, by people who are not us. Everything in `Corpus/` beside this
directory was written for this project and converts because it was written to;
these were not, which is the only reason they are worth having.

## Why these can be here at all

Shadertoy's default licence is CC BY-NC-SA 3.0, which is why the rest of the
outside corpus is fetched rather than vendored — see the licensing note in the
root README. Every shader here is the exception the same note already allows:
each one carries an explicit permissive licence in its own source, and that
header is left exactly as its author wrote it.

| Shader | Author | Licence |
| --- | --- | --- |
| `3l23RK.glsl` | iq | MIT |
| `4ssSRl.glsl` | iq | MIT |
| `7d23DR.glsl` | mrange | CC0-1.0 |
| `csscRl.glsl` | pizzahollandaise | MIT |
| `ctdfzN.glsl` | Peace | MIT |
| `dldyWN.glsl` | lf94 | MIT |
| `ftVXRc.glsl` | iq | MIT |
| `sdVyWt.glsl` | mrange | CC0-1.0 |

The file names are the Shadertoy ids, which is what the site names them, and the
second line of each file is the page it came from. A struct cannot be called
`4ssSRl`, so the ports are `S` plus the id.

## Where they came from

`Vipitis/Shadereval-inputs` on HuggingFace, which is the input set of the
ShaderEval benchmark and was collected through Shadertoy's own API — so it holds
only shaders their authors marked Public+API, and it carries the id, the author
and the licence beside each one. No key and no scraping: the dataset's REST
endpoint pages them out as JSON.

It is the image pass only. A Shadertoy with buffers arrives here as the pass
that would have read them, which is a thing to remember when one of them looks
wrong.

## What the whole set said

204 distinct shaders in that dataset, and the numbers underneath them are the
first real reading the coverage table has had:

- **104** report a gap and cannot be converted at all.
- **100** convert with nothing reported.
- **51** of those 100 produce C++ that a compiler accepts.
- **49** do not — which is a class of gap the report cannot see, since it has
  already said the shader converted.

These eight are from the 51, picked for permissive licences, no channels to
bind, and looking like different things. Adding more is a matter of choosing
them: the other 43 compile today.
