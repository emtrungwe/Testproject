#!/bin/bash
# coded by XuanMike

#@> COLORS

pr_fmt=" [+] %-60s : " # print format

export LC_TIME="en_US.UTF-8"

#@> Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
      exit 1
fi

function usage {
    echo -e "\
            Usage  : $0 [Option] 			\n\
            Options:						 			\n\
            \t -f : \t\t Full scan mode (include custom signature) 	\n\
            \t -l : \t\t Light resources usage mode (slower) 	\n\
            \t -o : \t\t Output folder 	\n\
            \t -c : \t\t clean tool folder 	\n\
            \t -u [account]: \t User account for ftp server (user:passwd)	\n\
            \t -h [server]: \t Server to get data 	\n\
            Example: $0 -u user:passwd -h ftp://example.com/files/				\n\
            Example: $0 -f -u user:passwd -h ftp://example.com	 				\n"	1>&2

    exit 1
}

limit_cpu=70
outdir="."
mode="lite"
thor_cmd=""
clean_tool=false
#> ARGUMENT FLAGS
while [ -n "$1" ]; do
    case $1 in
            
            -f|--full)
                mode="full"
                shift ;;

            -l|--limit)
                limit_cpu=40
                shift ;;
            -c|--clean)
                clean_tool=true
                shift ;;

            -o|--outdir)
                outdir=$2
                shift ;;

            -u|--user)
                user=$2
                shift ;;
                
            -h|--host)
                host=$2
                shift ;;

            -h|--help)
                usage
                shift ;;
            
            *)
                usage
    esac
    shift
done

#@> VARIABLES

SCRIPT=$(readlink -f "$0")
BASEDIR="$(dirname "$SCRIPT")"
TEMPDIR="vci_"

echo "Running $SCRIPT"

if [[ $mode == "full" ]]
then 
    TEMPNAME="LogsFull_$(hostname -I | awk '{print $1}')_$(hostname)_$(date +%F)"
else 
    TEMPNAME="Logs_$(hostname -I | awk '{print $1}')_$(hostname)_$(date +%F)"
fi

OUTDIR="$BASEDIR/$TEMPDIR/$TEMPNAME"

mkdir -p $OUTDIR

thor_file="thor-pack.tar"
thor_lic="e9.lic"

custom_sig="custom-signatures"

custom_sig_path="$BASEDIR/custom-signatures.tar"
thor_pack="$BASEDIR/$thor_file"
lic_path="$BASEDIR/$thor_lic"
publickey="$BASEDIR/public.pem"
lqhunt_ssh="$BASEDIR/lqhunt_ssh.sh"
cllf_config="$BASEDIR/CLLF.config"
cllf="$BASEDIR/CLLF.sh"

thor_folder="$TEMPDIR/thor_pack"
thordb="$OUTDIR/$TEMPNAME.db"

# DOWNLOAD_THOR(){
# 	curl -O -u $user $host/$thor_file -o $BASEDIR/$thor_pack 2>/dev/null
# 	if [ -f $thor_pack ]; then
# 	 	echo -e "Download file successed." 
# 	else
# 		echo -e "ERROR - Download file error, check server or user account."
# 		exit 1
# 	fi

# 	curl -O -u $user $host/$thor_lic -o $BASEDIR/$thor_lic 2>/dev/null
# 	if [ -f $lic_path ]; then
# 	 	echo -e "Download license successed." 
# 	else
# 		echo -e "ERROR - Download license error, check server or user account."
# 		exit 1
# 	fi
# }

SAVE_RESULT(){
    # Archive/Compress files
    echo -e "Creating $OUTDIR.tar.gz "
    tar -czf "$OUTDIR.tar.gz" -C "$TEMPDIR" "$TEMPNAME"
    sleep 2
    
    if [ -d $OUTDIR ]; then
        echo -e "Archived results, clean result folder $OUTDIR"
        rm -rf $OUTDIR
    fi

    return 
    while true
    do 
        if [ -z "$user" ]; then
            echo -e "FTP upload failed: User account is required ("-u username:password")."
            break
        fi
        if [ -z "$host" ]; then
            echo -e "FTP upload failed: Host is required ("-h ftp://example.com:port")."
            break
        fi
        # upload to ftp
        if curl -T $OUTDIR.tar.gz -u $user $host/$OUTDIR.tar.gz 2>/dev/null
        then 
            echo -e "Upload result successed." 
        else 
            echo -e "FTP upload failed: CURL UploadFailed "
        fi
        break
    done
}

RUN_THOR(){
    thor_cmd=""

    if uname -a | grep -q "x86_64"
    then                                                 
        thor_cmd=$thor_folder/thor-lite-linux-64
    else
        thor_cmd=$thor_folder/thor-lite-linux
    fi	

    if [ -d $thor_folder ]; then
        rm -rf $thor_folder
    fi

    mkdir -p $thor_folder

    tar -xf $thor_pack -C $thor_folder


    if [[ $mode == "full" ]]
    then
        # unpack custom signature
        echo -e "$custom_sig_path"

        tar -xf $custom_sig_path -C $thor_folder/$custom_sig

        # thor_cmd+=""
        echo -e "----------------------------Run in Full Mode-------------------------------"
    else
        # thor_cmd+=""
        echo -e "----------------------------Run in Lite Mode-------------------------------"
    fi
    chmod +x $thor_cmd
    /bin/bash -c "$thor_cmd --max_file_size 5242880 --silent --encrypt --pubkey $publickey --license-path $lic_path --jsonv2 --jsonfile -e $OUTDIR -c $limit_cpu --dbfile $thordb --resume"
}

# Clean up
CLEAN_UP(){ #Production
    
    # Clean-up directory if the tar exists
    if [ -f $OUTDIR.tar.gz ]; then
        if [ -f $lic_path ]; then
            rm -rf $lic_path
        fi
        if [ -f $custom_sig_path ]; then
            rm -rf $custom_sig_path
        fi
        if [ -f $thor_pack ]; then
            rm -rf $thor_pack
        fi
        if [ -f $publickey ]; then
            rm -rf $publickey
        fi
        if [ -f $lqhunt_ssh ]; then
            rm -rf $lqhunt_ssh
        fi
        if [ -f $cllf ]; then
            rm -rf $cllf
        fi
        if [ -f $cllf_config ]; then
            rm -rf $cllf_config
        fi

        if [ -d $thor_folder ]; then
            rm -rf $thor_folder
        fi
        /bin/bash -c "ping 127.0.0.1 -c 10 > /dev/null && rm -f $SCRIPT" &
    fi
}

while true
do
    if [ ! -f "$cllf" ]; then
        if [ ! -f "$OUTDIR/cllf.tar.gz" ]; then
            chmod +x $cllf
            /bin/bash -c "$cllf -o $OUTDIR/cllf"
        fi
    fi
    
    RUN_THOR
    sleep 5
    SAVE_RESULT
    sleep 5
    break 0 2>/dev/null
done
if $clean_tool; then
    CLEAN_UP
fi
sleep 5
exit 0
