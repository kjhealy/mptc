# NOTE: install the pandoc-crossref filter if you don't already have it
# e.g. brew install pandoc-crossref

# The output file `mypaper.pdf` depends on `mypaper.md` and `fig1.pdf`
mypaper.pdf: mypaper.md fig1.pdf 
	pandoc -F pandoc-crossref mypaper.md -o mypaper.pdf

# The output file `fig1.pdf` depends on `fig1.r`
fig1.pdf: fig1.r
	R CMD BATCH fig1.r


# Clean target
.PHONY: clean

clean:
	rm -f mypaper.pdf
	rm -f fig1.pdf
	rm -f fig1.r.Rout
