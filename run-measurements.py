#!/usr/bin/env python
import itertools
import os
import random
from subprocess import check_call

STRESS = {
      1,
     32,
     64,
# Extra
     96,
    128,
    192,
# Extra
    208,
# Extra
    224,
    256,
# Extra
#    288,
    320,
    384,
}


EXECTUABLE_SIZES = {
      1,
      2,
      4,
      8,
     16,
     32,
# Extra
     48,
     64,
    128,
# Extra
    192,
#    208,
#    224,
    256,
#    288,
#    320,
    384,
}

MEASUREMENTS = 50

## 2020-05-12: TM: Those measurements we need for the candlesticks
EXECTUABLE_SIZES = { 192, 320,
}
STRESS = {  128,
}
stress_exesizes = list(itertools.product(STRESS, EXECTUABLE_SIZES))
#stress_exesizes = [(s,e) for (s,e) in stress_exesizes if s+e > 150]
#print (len(stress_exesizes))
#asdf
#stress_exesizes = random.sample(
#    list(itertools.product(STRESS, EXECTUABLE_SIZES)),
#    3)

random.shuffle(stress_exesizes)

for i, (stress, exesize) in enumerate(stress_exesizes, start=1):
    print ("")
    print ("====================================")
    print ("     Run %3d/%d" % (i, len(stress_exesizes)))
    print ("                                    ")
    print ("           Stress %3d  -  Exe: %3d  " % (stress, exesize) )
    print ("====================================")
    print ("")
    print ("")

    imagename = os.path.expanduser(f"~/data/ima-appraisal-hack-tcb-tmm-stress-{stress}-exe-{exesize}.img")
    prepimage = os.path.expanduser("~/data/ima-appraisal-hack-tcb-tmm.img-prepared")


    cmd = f"env --unset=DISPLAY  MAKEIMAGE_STEP=modify PREPIMAGE={prepimage}  MANIPULATE_MEGABYTES={exesize} STRESS_MEGABYTES={stress}  ./makeimage-tcb.sh ~/data/focal-server-cloudimg-amd64.img  ./cloudimageboot-ima-guest.iso  {imagename}"
    
    print (cmd)
    check_call(cmd.split())

    for k in range(MEASUREMENTS):
        print ("---------------------------")
        print (" %3d/%3d  Measurement %2d/%2d" % (i, len(stress_exesizes), k+1, MEASUREMENTS))
        print ("---------------------------")
        measurement_cmd = f"/usr/bin/time  ./run-measurement.sh {imagename} {exesize} {stress}"
        print (measurement_cmd)
        check_call(measurement_cmd.split())

    os.unlink(imagename)
    os.unlink(imagename+"-fat_image.raw")
