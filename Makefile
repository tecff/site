GLUON_BUILD_DIR := gluon-build
GLUON_GIT_URL := https://github.com/freifunk-gluon/gluon.git
GLUON_GIT_REF := 04c88b62fac33ffef912402284b20fd1ff260e50

PATCH_DIR := ./patches
SECRET_KEY_FILE ?= ${HOME}/.gluon-secret-key

ifeq (,$(GLUON_TARGETS))
  GLUON_TARGETS := \
	ath79-generic \
	ath79-nand \
	bcm27xx-bcm2708 \
	bcm27xx-bcm2709 \
	ipq40xx-generic \
	ipq40xx-mikrotik \
	ipq806x-generic \
	lantiq-xrx200 \
	lantiq-xway \
	mpc85xx-p1010 \
	mpc85xx-p1020 \
	mediatek-mt7622 \
	ramips-mt7620 \
	ramips-mt7621 \
	ramips-mt76x8 \
	x86-64
ifneq (,$(BROKEN))
  GLUON_TARGETS += \
	bcm27xx-bcm2710 \
	mvebu-cortexa9 \
	ramips-rt305x \
	sunxi-cortexa7 \
	x86-generic \
	x86-geode \
	x86-legacy
endif
endif

GLUON_AUTOUPDATER_ENABLED := 1
GLUON_RELEASE := $(shell git describe --tags 2>/dev/null)
ifneq (,$(shell git describe --exact-match --tags 2>/dev/null))
  GLUON_AUTOUPDATER_BRANCH := stable
else ifeq (,${GLUON_AUTOUPDATER_BRANCH})
  GLUON_AUTOUPDATER_ENABLED := 0
  GLUON_RELEASE := snapshot~$(shell date '+%Y%m%d')
endif

MAKE_PID := $(shell echo $$PPID)
JOB_FLAG := $(filter -j%, $(subst -j ,-j,$(shell ps T | grep "^\s*$(MAKE_PID).*$(MAKE)")))
JOBS     := $(subst -j,,${JOB_FLAG})
ifeq (,$(strip ${JOBS}))
  JOBS := $(shell cat /proc/cpuinfo | grep processor | wc -l)
endif

GLUON_MAKEFLAGS := -j${JOBS} -C ${GLUON_BUILD_DIR} \
			GLUON_RELEASE=${GLUON_RELEASE} \
			GLUON_AUTOUPDATER_ENABLED=${GLUON_AUTOUPDATER_ENABLED} \
			GLUON_AUTOUPDATER_BRANCH=${GLUON_AUTOUPDATER_BRANCH}

# this special target makes sure that this Makefile is run serially
.NOTPARALLEL:

all: build move-output

info:
	@echo
	@echo '#########################'
	@echo '# TECFF Firmware build'
	@echo '# GLUON_RELEASE: ${GLUON_RELEASE}'
	@echo '# GLUON_AUTOUPDATER_BRANCH:  ${GLUON_AUTOUPDATER_BRANCH}'
	@echo '# GLUON_GIT_URL: ${GLUON_GIT_URL}'
	@echo '# GLUON_GIT_REF: ${GLUON_GIT_REF}'
	@echo '#########################'
	@echo

build: info gluon-prepare
	@echo '# starting builds...'
	+for target in ${GLUON_TARGETS}; do \
		echo ""Building target $$target""; \
		$(MAKE) ${GLUON_MAKEFLAGS} GLUON_TARGET="$$target"; \
	done

manifest:
	@echo '# creating manifest...'
	$(MAKE) ${GLUON_MAKEFLAGS} manifest

move-output:
	@echo '# moving output out of build directory...'
	mv ${GLUON_BUILD_DIR}/output .

sign: build manifest move-output
	@echo '# signing manifest...'
	${GLUON_BUILD_DIR}/contrib/sign.sh ${SECRET_KEY_FILE} output/images/sysupgrade/${GLUON_AUTOUPDATER_BRANCH}.manifest

${GLUON_BUILD_DIR}:
	@echo '# cloning sources...'
	git clone ${GLUON_GIT_URL} ${GLUON_BUILD_DIR}

gluon-prepare: output-clean ${GLUON_BUILD_DIR}
	@echo '# preparing sources...'
	(cd ${GLUON_BUILD_DIR} \
	  && git remote set-url origin ${GLUON_GIT_URL} \
	  && git fetch origin \
	  && git checkout -q ${GLUON_GIT_REF})
	$(MAKE) gluon-patch
	ln -sfT .. ${GLUON_BUILD_DIR}/site
	$(MAKE) ${GLUON_MAKEFLAGS} update

gluon-patch:
	scripts/apply_patches.sh ${GLUON_BUILD_DIR} ${PATCH_DIR}

clean:
	@echo '# starting clean...'
	+for target in ${GLUON_TARGETS}; do \
		echo ""Cleaning target $$target""; \
		$(MAKE) -C ${GLUON_BUILD_DIR} clean GLUON_TARGET="$$target"; \
	done

gluon-clean:
	@echo '# removing build directory...'
	rm -rf ${GLUON_BUILD_DIR}
	@echo '# build directory removed.'

output-clean:
	@echo '# removing output of last build...'
	rm -rf output
	@echo '# output of last build removed.'

dirclean: gluon-clean output-clean
