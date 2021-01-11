# x86JunkGen

x86-32 executable junk code generator. 

Supports generating ALU (add, sub, etc) and MOV instructions interacting with random general purpose registers and immediate values.

## Compiling

Compile using FASM (flatassembler.net) and link the obj to your project.

```
fasm junk_generator.asm
```

## Exported Functions
```C
int gen_junk(__out_deref void* lpOut, size_t cbOut);
```

![Sample generated code](https://i.imgur.com/Pnlsmnf.png)
