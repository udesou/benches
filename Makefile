.PHONY: clean clean-dune clean-with-deps

clean: clean-dune clean-with-deps
	@echo "Cleaning benchmark build artifacts under $(CURDIR)"
	@find . -type f \
		-not -path "./.git/*" \
		\( \
			-name "*.o" -o \
			-name "*.obj" -o \
			-name "*.a" -o \
			-name "*.so" -o \
			-name "*.cmi" -o \
			-name "*.cmo" -o \
			-name "*.cmx" -o \
			-name "*.cmxa" -o \
			-name "*.cma" -o \
			-name "*.cmt" -o \
			-name "*.cmti" -o \
			-name "*.annot" -o \
			-name "*.opt" -o \
			-name "*-ocaml-*" \
		\) -delete

clean-dune:
	@echo "Cleaning dune build directories under $(CURDIR)"
	@find . -type d \( -name "_build" -o -name "_build-running" \) -prune -exec rm -rf {} +

# Remove generated input data files produced by build.deps.sh scripts.
# These are runtime-version-independent and recreated automatically on next build.
clean-with-deps:
	@echo "Cleaning generated input data under $(CURDIR)/with_deps"
	@rm -f with_deps/graph500seq/edges.data
