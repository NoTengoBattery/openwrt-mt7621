# Functions to balance IRQs across CPUs

. /lib/functions.sh
board=$(board_name)

balance_irq() {
  _find_irq() {
    local name=$1
    awk -F'[: ]' '/'"$name"'/{print $2}' /proc/interrupts
  }
  _set_affinity() {
    local cpu_mask=$1
    _cpu_iterator() {
      local internal_irq=$1; shift
      _print_irq(){
        printf $(printf '%x' $((1 << $2))) > /proc/irq/$1/smp_affinity
        irq_name=$(awk '/'$1':/{print $9}' /proc/interrupts)
        printf "balance_irq: IRQ $1 ($irq_name), affinity for CPU $2" > /dev/kmsg
      }
      _print_irq $internal_irq $1; shift
      while read -r irq && [ "x" != "x$1" ]; do
        _print_irq $irq $1; shift
      done
      export irq
    }
    while true; do
      if [ "x" = "x$irq" ]; then
        read -r irq || break
      fi
      _cpu_iterator $irq $(echo "$cpu_mask" | grep -o '.')
    done
  }

  case "$board" in
  glinet,gl-b1300|\
  glinet,gl-s1300)
    _find_irq bam_dma     | _set_affinity 21
    _find_irq spi         | _set_affinity 3
    _find_irq serial      | _set_affinity 3
    _find_irq ath10k_ahb  | _set_affinity 30
    _find_irq edma_eth_tx | _set_affinity 1
    _find_irq edma_eth_rx | _set_affinity 2
    _find_irq keys        | _set_affinity 3
    _find_irq usb         | _set_affinity 3
    _find_irq mmc         | _set_affinity 2
    _find_irq sdhci       | _set_affinity 2
    ;;
  linksys,ea6350v3)
    _find_irq bam_dma     | _set_affinity 21
    _find_irq serial      | _set_affinity 3
    _find_irq pci         | _set_affinity 2
    _find_irq ath10k_ahb  | _set_affinity 10
    _find_irq edma_eth_tx | _set_affinity 023
    _find_irq edma_eth_rx | _set_affinity 23
    _find_irq keys        | _set_affinity 3
    _find_irq usb         | _set_affinity 3
    ;;
  linksys,ea8300|\
  linksys,mr8300)
    _find_irq bam_dma     | _set_affinity 21
    _find_irq spi         | _set_affinity 3
    _find_irq serial      | _set_affinity 3
    _find_irq ath10k_ahb  | _set_affinity 30
    _find_irq edma_eth_tx | _set_affinity 1
    _find_irq edma_eth_rx | _set_affinity 2
    _find_irq keys        | _set_affinity 3
    _find_irq usb         | _set_affinity 3
    ;;
  zbtlink,zbt-wg3526-16m|\
  zbtlink,zbt-wg3526-32m)
    _find_irq usb         | _set_affinity 3
    ;;
  esac
}
