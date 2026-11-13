# How to read the scripts

You can run everything in this repository without reading the code. If you
want to understand it, open a script in any text editor and read it from top
to bottom: it runs in exactly that order, and every step has a note above
it.

## What the symbols and commands mean

| You see | It means |
|---|---|
| `# some text` | A note for humans. The computer skips it. |
| `THREADS=4` | Store the value 4 under the name THREADS. |
| `THREADS=$(nproc)` | Run the command inside `$( )` and store its answer. `nproc` gives the number of processor cores. |
| `$THREADS` | Use the stored value here. |
| `\` at the end of a line | The command continues on the next line. |
| `--processes 4` | An option: a setting passed to a program. |
| `if [ ... ]; then ... fi` | Only do the part in the middle if the test is true. |
| `*.pdf` | Every file whose name ends in `.pdf`. |
| `wget` | Download a file. |
| `gunzip` | Unpack a `.gz` file. |
| `a \| b` | Hand the output of command `a` to command `b`. |
| `> file` | Write the output into `file`. |
| `cp` / `mv` / `mkdir` | Copy a file / rename or move a file / make a folder. |
| `conda activate name` | Switch to the set of installed programs called `name`. |

## The ten steps

Every analysis follows the same ten steps:

1. Create the project folders
2. Download the genome and the gene annotation
3. Download the reads
4. Check the read quality
5. Align the reads to the genome
6. Calculate coverage
7. Count the reads per gene
8. Compare the conditions with DESeq2
9. Draw the plots
10. Copy the key results to `results`

[Back to the main page](../readme.md)
