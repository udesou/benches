.PHONY: clean clean-dune

clean: clean-dune
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
			-name "*-ocaml-*" \
		\) -delete

clean-dune:
	@echo "Cleaning dune build directories under $(CURDIR)"
	@find . -type d \( -name "_build" -o -name "_build-running" \) -prune -exec rm -rf {} +
