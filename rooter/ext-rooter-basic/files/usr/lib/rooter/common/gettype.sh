#!/bin/sh

ROOTER=/usr/lib/rooter

CURRMODEM=$1
CPORT=$(uci get modem.modem$CURRMODEM.commport)

ATCMDD="AT+CFUN=1"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
ATCMDD="ATI"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
OX=$($ROOTER/common/processat.sh "$OX")

MANUF=$(echo "$OX" | awk -F[:] '/Manufacturer:/ { print $2}')
if [ "x$MANUF" = "x" ]; then
	MANUF=$(uci get modem.modem$CURRMODEM.manuf)
fi

MODEL=$(echo "$OX" | awk -F[,\ ] '/^\+MODEL:/ {print $2}')
if [ "x$MODEL" != "x" ]; then
	MODEL=$(echo "$MODEL" | sed -e 's/"//g')
	if [ $MODEL = 0 ]; then
		MODEL = "mf820"
	fi
else
	MODEL=$(uci get modem.modem$CURRMODEM.model)
fi

uci set modem.modem$CURRMODEM.manuf=$MANUF
uci set modem.modem$CURRMODEM.model=$MODEL
uci commit modem

$ROOTER/signal/status.sh $CURRMODEM "$MANUF $MODEL" "Connecting"

IMEI=$(echo "$OX" | awk -F[,\ ] '/^\IMEI:/ {print $2}')
if [ "x$IMEI" != "x" ]; then
	IMEI=$(echo "$IMEI" | sed -e 's/"//g')
else
	IMEI="Unknown"
fi

IDP=$(uci get modem.modem$CURRMODEM.uPid)
IDV=$(uci get modem.modem$CURRMODEM.uVid)

echo $IDV" : "$IDP > /tmp/msimdatax$CURRMODEM
echo "$IMEI" >> /tmp/msimdatax$CURRMODEM

lua $ROOTER/signal/celltype.lua "$MODEL" $CURRMODEM
source /tmp/celltype$CURRMODEM
rm -f /tmp/celltype$CURRMODEM

uci set modem.modem$CURRMODEM.celltype=$CELL
uci commit modem

$ROOTER/luci/celltype.sh $CURRMODEM

ATCMDD="AT+CIMI"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
OX=$($ROOTER/common/processat.sh "$OX")
ERROR="ERROR"
if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
then
	IMSI="Unknown"
else
	OX=${OX//[!0-9]/}
	IMSIL=${#OX}
	IMSI=${OX:0:$IMSIL}
fi
echo "$IMSI" >> /tmp/msimdatax$CURRMODEM

ATCMDD="AT+CRSM=176,12258"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
OX=$($ROOTER/common/processat.sh "$OX")
ERROR="ERROR"
if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
then
	ICCID="Unknown"
else
	ICCID=$(echo "$OX" | awk -F[,\ ] '/^\+CRSM:/ {print $4}')
	if [ "x$ICCID" != "x" ]; then
		sstring=$(echo "$ICCID" | sed -e 's/"//g')
		length=${#sstring}
		xstring=
		i=0
		while [ $i -lt $length ]; do
			c1=${sstring:$i:1}
			let 'j=i+1'
			c2=${sstring:$j:1}
			xstring=$xstring$c2$c1
			let 'i=i+2'
		done
		ICCID=$xstring
	else
		ICCID="Unknown"
	fi
fi
echo "$ICCID" >> /tmp/msimdatax$CURRMODEM

ATCMDD="AT+CNUM"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
M2=$(echo "$OX" | sed -e "s/+CNUM: /+CNUM:,/g")
CNUM=$(echo "$M2" | awk -F[,] '/^\+CNUM:/ {print $3}')
if [ "x$CNUM" != "x" ]; then
	CNUM=$(echo "$CNUM" | sed -e 's/"//g')
else
	CNUM="*"
fi
echo "$CNUM" >> /tmp/msimdatax$CURRMODEM

mv -f /tmp/msimdatax$CURRMODEM /tmp/msimdata$CURRMODEM
