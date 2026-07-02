#!/usr/bin/env python
# 
# Fernando Carrio Argos - 2024
# CSIC - CERN
#

import Herakles
from optparse import OptionParser



IPaddressServer="localhost"


class IPbus:
    def __init__(self, ipaddress, verbose=False):
        self.ipbus = Herakles.Uhal("tcp://192.168.0.201:10203?target="+ipaddress+":50001")
        self.ipbus.SetVerbose(verbose)
        pass

    def Write(self,add,val): self.ipbus.Write(add,val)

    def Read(self, add): return self.ipbus.Read(add,1)
    def AsyncWrite(self, dba, val): self.ipbus.Write(0x00010002, [dba, val])


parser = OptionParser()
parser.add_option("-m", "--module", help="Module: GTH1 or GTH2", dest='module', type='string', action="store")

(options, args) = parser.parse_args()


def config_ppr(ipaddr):
        ipbus = IPbus(ipaddr)
        value = 0xFF
        ipbus.Write(0x83,(value<<24))
        ipbus.Write(0x40005,0x6)
        ipbus.Write(0x4,0x0)
        ipbus.AsyncWrite(0x115,50) 
        ipbus.AsyncWrite(0x15,0x800)#
        ipbus.AsyncWrite(0x15,0x00) 
        ipbus.AsyncWrite(0x121,0)
        

if options.module == "GTH2":
        ipaddr = "192.168.0.3"
        config_ppr(ipaddr)
elif options.module == "GTH1":
        ipaddr = "192.168.0.2"
        config_ppr(ipaddr)
elif options.module == "ALL":
        ipaddr = "192.168.0.2"
        config_ppr(ipaddr)
        ipaddr = "192.168.0.3"
        config_ppr(ipaddr)

elif options.module is None:
        print ("Module EB or LB\n")
        parser.print_help()
        exit(-1)




