hyacinth_run_post_install:
    #!/bin/bash
    bash -x /usr/immutablue-build-hyacinth-macaw/post_install.sh


hyacinth_full_update:
    #!/bin/bash 
    set -euxo pipefail 
    
    cd "$HOME/Source/Projects/immutablue/"
    make DO_INSTALL_ZFS=true all

    cd "$HOME/Source/Projects/hyacinth-macaw"
    make all


hyacinth_full_update_asahi:
    #!/bin/bash 
    set -euxo pipefail 
    
    cd "$HOME/Source/Projects/immutablue/"
    make ASAHI=1 all

    cd "$HOME/Source/Projects/hyacinth-macaw"
    make ASAHI=1 all

