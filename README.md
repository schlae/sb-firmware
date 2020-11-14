# SB DSP Firmware, Disassembled

There are two assembly files in the repository that are reverse engineered and
disassembled from real sound cards, both of which are very similar to the
Snark Barker. Variable names have been added and many (non-local) labels have
been added.

* sbv202.asm - SB V2.02 DSP with detailed comments.
* anchor\_modded.asm - Firmware from many Chinese clone sound cards (ZhuHai
 Anchor Electronics).

These files are provided purely for educational purposes, and could be quite
useful for perfecting software emulations or for understanding obscure features
and behavior. The comments also call out several bugs.

Both files may be assembled using as31, and produce an exact match with the
original machine code.

Before digging into the code, it may help your understanding of how these
sound cards work by reading the [SB 1.0 Principles of Operation](http://tubetime.us/index.php/2019/01/19/sound-blaster-1-0-principles-of-operation/). Firmware
principles of operation are detailed [here](https://github.com/schlae/snark-barker/blob/master/Sb202Spec.md). In addition, since the firmware is meant for
cards similar to the Snark Barker, it is useful to refer to the [schematic](https://github.com/schlae/snark-barker/blob/master/SnarkBarker.pdf).
