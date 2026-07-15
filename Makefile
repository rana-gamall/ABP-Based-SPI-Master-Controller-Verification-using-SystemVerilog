# =============================================================================
# Makefile 
# =============================================================================

SIMULATOR ?= questa
SEED      ?= 0
TEST      ?= sanity_test
WAVES     ?= 0

# Resolve the project root from this file's location.
PROJ_ROOT  ?= .
HARNESS    ?= $(PROJ_ROOT)/harness
STUDENT_TB ?= .

# DUT sources (three-file golden RTL). The grader overrides DUT_SRCS to
# point at faulty_rtl/*_buggy.sv when it injects a bug.
DUT_SRCS   ?= \
  $(PROJ_ROOT)/golden_rtl/spi_core.sv \
  $(PROJ_ROOT)/golden_rtl/apb_regfile.sv \
  $(PROJ_ROOT)/golden_rtl/spi_master.sv
DUT_SRC    ?=
EFF_DUT_SRCS = $(if $(strip $(DUT_SRC)),$(DUT_SRC),$(DUT_SRCS))

BONUS_TEST ?= ral_hw_reset_test

# ---- student source lists ---------------------------------------------------
TB_SRCS    ?= \
  $(STUDENT_TB)/tb/apb_master_bfm.sv \
  $(STUDENT_TB)/tb/spi_slave_bfm.sv \
  $(STUDENT_TB)/tb/tb_top.sv

ENV_SRCS   ?= \
  $(STUDENT_TB)/env/ref_model.sv \
  $(STUDENT_TB)/env/coverage.sv \
  $(STUDENT_TB)/env/coverage2_regfile.sv \
  $(STUDENT_TB)/env/coverage_spi_core.sv

SEQ_SRCS   ?= \
  $(STUDENT_TB)/sequences/stim_lib.sv

ASSERT_SRCS?= \
  $(STUDENT_TB)/assertions/spi_sva.sv

# Test files are pulled in via `include from tb_top.sv (see template comments).
INC_DIRS   ?= +incdir+$(HARNESS) +incdir+$(STUDENT_TB) \
              +incdir+$(STUDENT_TB)/env +incdir+$(STUDENT_TB)/tb \
              +incdir+$(STUDENT_TB)/sequences +incdir+$(STUDENT_TB)/tests

# ---- regression list --------------------------------------------------------
REGRESSION_TESTS = \
  sanity_test \
  randomized_sanity_test \
  reg_access_test \
  randomized_reg_access_test \
  mode_coverage_test \
  width_coverage_test \
  randomized_width_coverage_test \
  fifo_stress_test \
  interrupt_test \
  clk_div_corner_test \
  loopback_test \
  delay_transfer_test \
  error_injection_test

REGRESSION_SEEDS ?= 1

# Sentinel file used to detect whether compile has actually run. Touched at
# the end of the compile recipe; `regress` depends on it (not on `compile`)
# so re-running regress without changing sources is a no-op for compilation.
BUILD_DIR   = build
COMPILE_TAG = $(BUILD_DIR)/.compiled

# ============================================================================
# Questa flow (default) - BATCH MODE ONLY
# ============================================================================
ifeq ($(SIMULATOR),questa)

VLOG_FLAGS  = -sv -timescale=1ns/1ps +acc=rn +define+SIM $(INC_DIRS)
COV_FLAG    = +cover=bcestf
VSIM_COV    = -coverage

# `vsim -c` = console (no GUI). `-onfinish stop` makes $finish halt the
# simulation but keeps the do-script running, so `coverage save` actually
# executes before `quit -f` exits vsim. With `-onfinish exit`, vsim quits
# immediately on $finish and the rest of the do-script (including the
# coverage save) is skipped.
VSIM_BATCH  = -c -onfinish stop

# ---- compile ---------------------------------------------------------------
# Independent target. Touches a sentinel so other targets can depend on it
# without re-running vlog every time.
compile: $(COMPILE_TAG)

$(COMPILE_TAG):
	@mkdir -p $(BUILD_DIR)
	@if [ ! -d work ]; then vlib work; fi
	# NOTE: ENV_SRCS and SEQ_SRCS are intentionally NOT compiled directly.
	# tb_top.sv pulls them in via `include so their class/typedef names land
	# in tb_top's compilation unit. Compiling them standalone here would
	# create a second compilation unit with the same names and trigger
	# "multiply defined" / "already declared" errors.
	vlog $(VLOG_FLAGS) $(COV_FLAG) \
	   $(HARNESS)/apb_if.sv \
	   $(HARNESS)/spi_if.sv \
	   $(EFF_DUT_SRCS) \
	   $(HARNESS)/dut_wrapper.sv \
	   $(ASSERT_SRCS) \
	   $(TB_SRCS)
	@touch $(COMPILE_TAG)

# ---- run -------------------------------------------------------------------
# INDEPENDENT of compile. If `work` is missing the user gets a clear error
# pointing them at `make compile`. This way `make run` is fast and never
# touches the source files.
run:
	@if [ ! -d work ] || [ ! -f $(COMPILE_TAG) ]; then \
	    echo "ERROR: design not compiled. Run 'make compile' first." ; \
	    exit 1 ; \
	fi
	vsim $(VSIM_BATCH) $(VSIM_COV) work.tb_top \
	     -do "run -all; coverage save cov_$(TEST)_$(SEED).ucdb; quit -f" \
	     +TESTNAME=$(TEST) +UVM_TESTNAME=$(TEST) +SEED=$(SEED) \
	     $(if $(filter 1,$(WAVES)), -wlf waves_$(TEST)_$(SEED).wlf,)

# Convenience: compile-then-run in one shot.
all: compile run
build: compile

run_bonus:
	@if [ ! -d work ] || [ ! -f $(COMPILE_TAG) ]; then \
	    echo "ERROR: design not compiled. Run 'make compile' first." ; \
	    exit 1 ; \
	fi
	vsim $(VSIM_BATCH) work.tb_top -do "run -all; quit -f" \
	     +TESTNAME=$(BONUS_TEST) +UVM_TESTNAME=$(BONUS_TEST) +SEED=$(SEED)

# Regression also depends on the sentinel, not on `compile`, so a repeated
# `make regress` after a clean compile does NOT trigger recompilation.
# Regression has NO compile dependency. The grader contract (Section 5)
# measures the 5-min wall-time budget starting at `make regress`, so any
# compile triggered here eats into that budget. Always run `make compile`
# explicitly before `make regress`.
regress:
	@if [ ! -f $(COMPILE_TAG) ]; then \
	    echo "ERROR: design not compiled. Run 'make compile' first." ; \
	    exit 1 ; \
	fi
	@mkdir -p $(BUILD_DIR)
	@for t in $(REGRESSION_TESTS) ; do \
	    echo "=== Running $$t for $(REGRESSION_SEEDS) seeds ===" ; \
	    for s in `seq 1 $(REGRESSION_SEEDS)` ; do \
	        $(MAKE) -s run TEST=$$t SEED=$$s WAVES=0 \
	          > $(BUILD_DIR)/log_$${t}_$${s}.log 2>&1 ; \
	    done ; \
	done
	@ucdbs=`ls cov_*.ucdb 2>/dev/null` ; \
	if [ -n "$$ucdbs" ] ; then \
	    echo "Merging $$ucdbs" ; \
	    vcover merge -out $(BUILD_DIR)/merged.ucdb $$ucdbs ; \
	else \
	    echo "WARNING: no cov_*.ucdb files found - skipping merge" ; \
	fi

cov:
	@if [ -f $(BUILD_DIR)/merged.ucdb ]; then \
	    vcover report -details $(BUILD_DIR)/merged.ucdb > coverage_report.txt ; \
	    echo "Coverage report: coverage_report.txt" ; \
	else \
	    echo "No merged.ucdb - run 'make regress' first" ; exit 1 ; \
	fi

clean:
	rm -rf work $(BUILD_DIR) *.wlf *.vstf *.ucdb transcript coverage_report.txt

endif

.PHONY: compile run all build run_bonus regress cov clean