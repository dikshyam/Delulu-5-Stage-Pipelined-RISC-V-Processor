.PHONY: all run clean submit

# PROG=/shared/cse502/tests/project/prog2 20
# PROG=/shared/cse502/tests/project/prog5
# PROG=/shared/cse502/tests/project/prog3
PROG=/shared/cse502/tests/project/prog1
# PROG=/shared/cse502/tests/project/prog4


#PROG=/shared/cse502/tests/bbl.bin

TRACE?=--trace
HAVETLB=n
FULLSYSTEM=n

VFILES=$(wildcard *.sv)
CFILES=$(wildcard *.cpp)

all: obj_dir/Vtop

obj_dir/Vtop: obj_dir/Vtop.mk
	$(MAKE) -j5 -C obj_dir/ -f Vtop.mk CXX="ccache g++"

obj_dir/Vtop.mk: $(VFILES) $(CFILES) 
	verilator -Wall -Wno-LITENDIAN -Wno-lint -O3 $(TRACE) --no-skip-identical --cc top.sv \
	--exe $(CFILES) /shared/cse502/DRAMSim2/libdramsim.so \
	-CFLAGS -I/shared/cse502 -CFLAGS -std=c++11 -CFLAGS -g3 \
	-LDFLAGS -Wl,-rpath=/shared/cse502/DRAMSim2 \
	-LDFLAGS -lncurses -LDFLAGS -lelf -LDFLAGS -lrt

run: obj_dir/Vtop
	cd obj_dir/ && env HAVETLB=$(HAVETLB) FULLSYSTEM=$(FULLSYSTEM) ./Vtop $(PROG)

clean:
	rm -rf obj_dir/ dramsim2/results trace.vcd core 

SUBMITTO=/submit
SUBMIT_POINTS=-70
SUBMIT_SUFFIX=-course_project$(SUBMIT_POINTS)
submit: clean
	rm -f $(USER).tgz
	tar -czvf $(USER).tgz --exclude=.*.sw? --exclude=$(USER).tgz* --exclude=*~ --exclude=.git *
	mv -v $(USER).tgz $(SUBMITTO)/$(USER)$(SUBMIT_SUFFIX)=`date +%F=%T`.tgz
