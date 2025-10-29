#!/usr/bin/env python3
import sys
import argparse
import gzip

def vopen(path):
    if path == "-":
        return sys.stdin
    return gzip.open(path, "rt") if path.endswith(".gz") else open(path, "r")

class Rec:
    __slots__ = ("chrom","pos","ref","alt")
    def __init__(self, chrom, pos, ref, alt):
        self.chrom = chrom
        self.pos = pos
        self.ref = ref
        self.alt = alt  # string ALT (single), not comma-joined; haploid vcfs assumed 1 ALT per line

def parse_vcf_single_alt(path):
    """
    Parse a haploid/site-only VCF into dict keyed by (chrom,pos).
    Assumes one ALT per line (no multiallelic) and no sample columns.
    Returns: dict[(chrom,int pos)] = Rec
    """
    d = {}
    with vopen(path) as f:
        for line in f:
            if not line or line[0] == '#':
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 5:
                continue
            chrom = parts[0]
            try:
                pos = int(parts[1])
            except ValueError:
                continue
            ref = parts[3].upper()
            alt_field = parts[4].upper()
            # Skip non-variant or symbolic
            if alt_field == "." or alt_field == "":
                continue
            # If input accidentally has multiallelic, take as-is but warn
            if "," in alt_field:
                # Keep first; emit warning
                sys.stderr.write(f"[warn] multiallelic ALT in haploid input at {chrom}:{pos}; taking first\n")
                alt = alt_field.split(",")[0]
            else:
                alt = alt_field
            key = (chrom, pos)
            if key in d:
                # Duplicate site in input; keep the first and warn
                sys.stderr.write(f"[warn] duplicate site in {path} at {chrom}:{pos}; keeping first\n")
                continue
            d[key] = Rec(chrom, pos, ref, alt)
    return d

def write_header(out, sample):
    out.write("##fileformat=VCFv4.2\n")
    out.write("##source=merge_haploid_vcfs\n")
    out.write('##FORMAT=<ID=GT,Number=1,Type=String,Description="Phased diploid genotype from two haploid callsets (hap1|hap2)">\n')
    out.write("#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t{}\n".format(sample))

def main():
    ap = argparse.ArgumentParser(description="Merge two haploid VCFs into one phased diploid VCF.")
    ap.add_argument("--hap1", required=True, help="haploid VCF for haplotype 1 (vcf or vcf.gz)")
    ap.add_argument("--hap2", required=True, help="haploid VCF for haplotype 2 (vcf or vcf.gz)")
    ap.add_argument("--sample", default="SAMPLE", help="sample name for output VCF")
    args = ap.parse_args()

    h1 = parse_vcf_single_alt(args.hap1)
    h2 = parse_vcf_single_alt(args.hap2)

    # Union of keys; sort by chrom then pos (simple lexicographic chrom sort)
    keys = sorted(set(h1.keys()) | set(h2.keys()), key=lambda x: (x[0], x[1]))

    out = sys.stdout
    write_header(out, args.sample)

    for key in keys:
        r1 = h1.get(key)
        r2 = h2.get(key)

        # Determine REF (must match if both present)
        if r1 and r2:
            if r1.ref != r2.ref:
                sys.stderr.write(f"[warn] REF mismatch at {key[0]}:{key[1]} (hap1={r1.ref}, hap2={r2.ref}); skipping site\n")
                continue
            ref = r1.ref
        elif r1:
            ref = r1.ref
        else:
            ref = r2.ref

        chrom, pos = key

        # Cases:
        # - only r1 present → ALT=[r1.alt], GT=1|0
        # - only r2 present → ALT=[r2.alt], GT=0|1
        # - both present and alts equal → ALT=[alt], GT=1|1
        # - both present and alts differ → ALT=[alt1,alt2], GT=1|2
        if r1 and not r2:
            alt_list = [r1.alt]
            gt = "1|0"
        elif r2 and not r1:
            alt_list = [r2.alt]
            gt = "0|1"
        else:
            if r1.alt == r2.alt:
                alt_list = [r1.alt]
                gt = "1|1"
            else:
                # distinct alts; build multiallelic; maintain (hap1, hap2) order
                if r1.alt == ref or r2.alt == ref:
                    # Shouldn't happen (would have been missing), but guard
                    sys.stderr.write(f"[warn] unexpected REF ALT at {chrom}:{pos}; skipping\n")
                    continue
                alt_list = [r1.alt]
                # avoid duplicate if somehow same again (already handled)
                if r2.alt not in alt_list:
                    alt_list.append(r2.alt)
                # genotype indexes: hap1->1, hap2->2 (correspond to positions in alt_list)
                # If r2.alt == r1.alt (shouldn’t, handled above), it would be 1|1
                gt = "1|2"

        alt_field = ",".join(alt_list)

        # Emit VCF line
        # Columns: CHROM POS ID REF ALT QUAL FILTER INFO FORMAT SAMPLE
        out.write(f"{chrom}\t{pos}\t.\t{ref}\t{alt_field}\t.\tPASS\t.\tGT\t{gt}\n")

if __name__ == "__main__":
    main()

