#!/bin/bash

# This script enforces security compliance policies by configuring account lockout settings, 
# screensaver policies, log retention, password encryption methods, SNMP security, and NTP synchronization.
# It ensures system-wide security measures across all major Linux distributions.

# ============== VARIABLES ===================================
LOG_FILE="/var/log/compliance_remediation.log"
RETENTION_DAYS=90
LOCKOUT_ATTEMPTS=5
UNLOCK_TIME=1800  # 30 minutes
IDLE_TIMEOUT=900  # 15 minutes
REQUIRED_ENCRYPT_METHOD="SHA512"
RETENTION_DAYS_REQUIRED=90

unalias -a

# ============ LOGGING FUNCTION ===============================
log_message() {
    local LOG_LEVEL="$1"
    local MESSAGE="$2"

    # Ensure log file exists
    [[ ! -f $LOG_FILE ]] && touch $LOG_FILE && chmod 644 $LOG_FILE

    # Write log entry
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LOG_LEVEL] $MESSAGE" | tee -a "$LOG_FILE"
}


# ============== DETECT LINUX DISTRIBUTION ==============
detect_distro() {
    log_message "INFO" "Detecting Linux distribution..."

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$(echo "$ID" | tr '[:upper:]' '[:lower:]')  # Normalize to lowercase
        VERSION=$(echo "$VERSION_ID" | cut -d'.' -f1)  # Extract major version

        case "$DISTRO" in
            "rhel"|"centos"|"ol"|"fedora"|"rocky"|"almalinux")
                log_message "INFO" "Detected RHEL-based Linux: $DISTRO $VERSION"
                ;;
            "ubuntu"|"debian")
                log_message "INFO" "Detected Debian-based Linux: $DISTRO $VERSION"
                ;;
            "suse"|"opensuse")
                log_message "INFO" "Detected SUSE-based Linux: $DISTRO $VERSION"
                ;;
            *)
                log_message "ERROR" "Unsupported Linux distribution: $DISTRO $VERSION"
                exit 1
                ;;
        esac
    else
        log_message "ERROR" "Cannot detect Linux distribution. /etc/os-release missing."
        exit 1
    fi
}


# ================ REMEDIATE LOG RETENTION ==================================
remediate_log_retention() {
    log_message "INFO" "============ LOG RETENTION POLICY ==========="
    log_message "INFO" "Checking and applying log retention policy..."

    # Backup the original file before modifications
    cp /etc/logrotate.conf /etc/logrotate.conf.bak


    # Check and update the 'rotate' parameter for retention days
    if grep -q "^rotate" /etc/logrotate.conf; then
        sed -i "s/^rotate.*/rotate $RETENTION_DAYS_REQUIRED/" /etc/logrotate.conf
    else
        echo "rotate $RETENTION_DAYS_REQUIRED" >> /etc/logrotate.conf
    fi

    # Ensure only 'daily' is set as the rotation frequency
    # Remove or replace any existing frequency directives (weekly, monthly, yearly)
    for freq in weekly monthly yearly; do
        if grep -q "^$freq" /etc/logrotate.conf; then
            sed -i "s/^$freq/#$freq/" /etc/logrotate.conf  # Comment out the old frequency
        fi
    done

    # Add or ensure 'daily' is present and active
    if grep -q "daily" /etc/logrotate.conf; then
        sed -i "s/^#*daily/daily/" /etc/logrotate.conf  # Uncomment if commented
    else
        echo "daily" >> /etc/logrotate.conf
    fi

    log_message "INFO" "Log retention updated to $RETENTION_DAYS_REQUIRED days with daily rotation."
}

# ================== REMEDIATE ACCOUNT LOCKOUT POLICY ==================
#remediating lockout parameters 
remediate_lockout_ubuntu(){
    COMMON_AUTH="/etc/pam.d/common-auth"
    COMMON_ACCOUNT="/etc/pam.d/common-account"
	cp -ap /etc/pam.d/common-auth /etc/pam.d/common-auth_$(date +%d_%m_%y_%s)
	cp -ap /etc/pam.d/common-account /etc/pam.d/common-account_$(date +%d_%m_%y_%s)
	        if ! grep -q "pam_faillock.so preauth" "$COMMON_AUTH"; then
            log_message "INFO" "Adding pam_faillock.so lockout rules to $COMMON_AUTH"
            sed -i '/pam_unix.so/a \
auth [default=die] pam_faillock.so authfail deny=5 unlock_time=1800 \
auth sufficient pam_faillock.so authsucc deny=5 unlock_time=1800' "$COMMON_AUTH"
            log_message "INFO" "Added pam_faillock settings to $COMMON_AUTH."
        else
            log_message "INFO" "pam_faillock.so is already configured in $COMMON_AUTH."
        fi
		    # ====== Ensure `pam_faillock.so` is configured in `/etc/pam.d/common-account` ======
        if [[ -f "$COMMON_ACCOUNT" ]] && ! grep -q "pam_faillock.so" "$COMMON_ACCOUNT"; then
            echo "account required pam_faillock.so" >> "$COMMON_ACCOUNT"
            log_message "INFO" "Added pam_faillock to $COMMON_ACCOUNT."
        else
            log_message "INFO" "pam_faillock is already present in $COMMON_ACCOUNT."
        fi
		systemctl restart ssh && log_message "INFO" "restarted sshd in ubuntu" || log_message "ERROR" "not able to restart sshd in ubuntu" 
}
remediate_lockout_rhel() {
    SSHD_PAM="/etc/pam.d/sshd"
    COMMON_AUTH="/etc/pam.d/common-auth"
    COMMON_ACCOUNT="/etc/pam.d/common-account"
    FAILLOCK_CONF="/etc/security/faillock.conf"
    TEMP_FILE="/tmp/sshd_pam_temp"
    BACKUP_FILE="/etc/pam.d/sshd.bak"
	
# File to modify
SSHD_PAM="/etc/pam.d/sshd"
BACKUP_FILE="/etc/pam.d/sshd.bak.$(date +%Y%m%d_%H%M%S)"

# Check if the PAM file exists
if [[ ! -f "$SSHD_PAM" ]]; then
    log_message "ERROR" "$SSHD_PAM not found! Exiting..."
    exit 1
fi

# Create a backup
cp "$SSHD_PAM" "$BACKUP_FILE" || {
    log_message "ERROR" "Failed to create backup at $BACKUP_FILE. Exiting..."
    exit 1
}
log_message "INFO" "Backup created at $BACKUP_FILE"

# Function to safely add lines to PAM file
    # ====== Find the auth section boundaries ======
    auth_start=$(grep -n "^auth" "$SSHD_PAM" | head -n 1 | cut -d: -f1)
    auth_end=$(grep -n "^\(account\|password\|session\)" "$SSHD_PAM" | head -n 1 | cut -d: -f1)

    if [[ -z "$auth_start" ]]; then
        log_message "ERROR" "No auth section found in $SSHD_PAM! Exiting..."
        return 1
    fi

    # If no clear end (e.g., no account/password/session), use the last line of the file
    if [[ -z "$auth_end" ]]; then
        auth_end=$(wc -l < "$SSHD_PAM")
    else
        auth_end=$((auth_end - 1))  # Last line of auth section
    fi

    log_message "INFO" "Auth section found from line $auth_start to $auth_end in $SSHD_PAM."

    # ====== Add preauth at the start and authfail at the end of auth section ======
    sudo awk -v start="$auth_start" -v end="$auth_end" '
        NR == start && !/pam_faillock.so preauth/ {print "auth required pam_faillock.so preauth silent deny=5 unlock_time=1800"; print; next}
        NR == end && !/pam_faillock.so authfail/ {print; print "auth required pam_faillock.so authfail deny=5 unlock_time=1800"; next}
        {print}
    ' "$SSHD_PAM" > "$TEMP_FILE"
	    # ====== Replace the original SSHD PAM file ======
    if [[ $? -eq 0 ]]; then
        mv "$TEMP_FILE" "$SSHD_PAM"
        chmod 644 "$SSHD_PAM"
        log_message "INFO" "Updated $SSHD_PAM with pam_faillock.so settings."
    else
        log_message "ERROR" "Failed to update $SSHD_PAM. Manual intervention required."
        return 1
    fi
	       # Add before the first 'account' line (for account check)
		    account_line=$(cat /etc/pam.d/sshd | grep -n account | head -1 | awk -F ":" '{print $1}')
            sed -i "${account_line}i account required pam_faillock.so" /etc/pam.d/sshd

# Restart SSHD service
systemctl restart sshd && log_message "INFO" "SSHD service restarted successfully."

log_message "INFO" "Modification complete. Check $SSHD_PAM for changes."
	
}


# ================ REMEDIATE SCREEN LOCK ==================
remediate_screen_lock() {
    log_message "INFO" "============ SCREEN LOCK POLICY ==========="    
    log_message "INFO" "Checking and applying screen lock policies..."
    GUI_FOUND=0

    # ====== Handling GNOME (Ubuntu, RHEL, Fedora) with gsettings and dconf ======
    if command -v gsettings &>/dev/null; then
	  if gsettings list-schemas 2>&1 | grep -iq "No schemas"
	     then     log_message "INFO"  "It is a CLI system"
	  else     log_message "INFO"  "This is GUI"
        CURRENT_IDLE_DELAY=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null)
        CURRENT_LOCK_ENABLED=$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null)

        if [[ "$CURRENT_IDLE_DELAY" != "uint32 $IDLE_TIMEOUT" ]]; then
            gsettings set org.gnome.desktop.session idle-delay $IDLE_TIMEOUT && log_message "Updated" "Modified GNOME idle delay (gsettings): $CURRENT_IDLE_DELAY → $IDLE_TIMEOUT"
		
        fi

        if [[ "$CURRENT_LOCK_ENABLED" != "true" ]]; then
            gsettings set org.gnome.desktop.screensaver lock-enabled true && log_message "Updated" "Enabled GNOME screensaver lock (gsettings)."
        fi

        # Verify if gsettings changes took effect (in case locked by dconf)
        NEW_IDLE_DELAY=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null)
        NEW_LOCK_ENABLED=$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null)

        if [[ "$NEW_IDLE_DELAY" != "uint32 $IDLE_TIMEOUT" || "$NEW_LOCK_ENABLED" != "true" ]] && command -v dconf &>/dev/null; then
            log_message "gsettings changes failed (possibly locked). Applying dconf system-wide settings..."

            # Create dconf config file
            sudo mkdir -p /etc/dconf/db/local.d
            cat <<EOF | sudo tee /etc/dconf/db/local.d/01-screen-lock > /dev/null
[org/gnome/desktop/session]
idle-delay=uint32 $IDLE_TIMEOUT

[org/gnome/desktop/screensaver]
lock-enabled=true
lock-delay=uint32 0
EOF

            # Lock the settings to enforce them
            sudo mkdir -p /etc/dconf/db/local.d/locks
            cat <<EOF | sudo tee /etc/dconf/db/local.d/locks/screen-lock > /dev/null
/org/gnome/desktop/session/idle-delay
/org/gnome/desktop/screensaver/lock-enabled
/org/gnome/desktop/screensaver/lock-delay
EOF

            # Update dconf database
            sudo dconf update
            log_message "Applied GNOME screen lock settings via dconf: idle-delay=$IDLE_TIMEOUT, lock-enabled=true"
        fi

        GUI_FOUND=1
	  fi
    fi

    # ====== Handling KDE Plasma (CentOS Stream, Fedora KDE, OpenSUSE) ======
    if command -v kwriteconfig5 &>/dev/null; then
        KDE_TIMEOUT=$(kwriteconfig5 --file kscreensaverrc --group ScreenSaver --key Timeout 2>/dev/null)
        KDE_LOCK=$(kwriteconfig5 --file kscreensaverrc --group ScreenSaver --key Lock 2>/dev/null)

        if [[ "$KDE_TIMEOUT" != "$IDLE_TIMEOUT" ]]; then
            kwriteconfig5 --file kscreensaverrc --group ScreenSaver --key Timeout $IDLE_TIMEOUT
            log_message "Updated" "Modified KDE screen lock timeout: $KDE_TIMEOUT → $IDLE_TIMEOUT"
        fi

        if [[ "$KDE_LOCK" != "true" ]]; then
            kwriteconfig5 --file kscreensaverrc --group ScreenSaver --key Lock true
            log_message "Enabled KDE screensaver lock."
        fi

        GUI_FOUND=1
    fi

    # ====== Handling XFCE (Debian XFCE, Ubuntu XFCE) ======
    if command -v xfconf-query &>/dev/null; then
        XFCE_TIMEOUT=$(xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-sleep-mode 2>/dev/null)
        XFCE_LOCK_CMD=$(xfconf-query -c xfce4-session -p /general/LockCommand 2>/dev/null)

        if [[ "$XFCE_TIMEOUT" != "$IDLE_TIMEOUT" ]]; then
            xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-sleep-mode -s $IDLE_TIMEOUT
            log_message "Modified XFCE screen lock timeout: $XFCE_TIMEOUT → $IDLE_TIMEOUT"
        fi

        if [[ "$XFCE_LOCK_CMD" != "xflock4" ]]; then
            xfconf-query -c xfce4-session -p /general/LockCommand -s "xflock4"
            log_message "Enabled XFCE screensaver lock."
        fi

        GUI_FOUND=1
    fi

    # ====== Handling CLI (Non-GUI Linux Servers) ======
    if [[ $GUI_FOUND -eq 0 ]]; then
        log_message "No GUI detected. Applying CLI-based screen timeout..."

        # Capture current TMOUT value
        CURRENT_TMOUT=$(grep -E "^export TMOUT=" /etc/profile 2>/dev/null || echo "Not Set")

        if [[ "$CURRENT_TMOUT" =~ "TMOUT=" ]]; then
            sed -i "s/^export TMOUT=.*/export TMOUT=$IDLE_TIMEOUT/" /etc/profile
            log_message "Modified CLI auto-logout: $CURRENT_TMOUT → export TMOUT=$IDLE_TIMEOUT"
        else
            echo "export TMOUT=$IDLE_TIMEOUT" >> /etc/profile
            log_message "Added CLI auto-logout after $IDLE_TIMEOUT seconds."
        fi
    fi
    echo "export TMOUT=900" >> /etc/profile
    log_message "Updated" "Screen lock policies successfully applied."
}

# ====== REMEDIATE SNMP SETTINGS ============================
remediate_snmp() {
    log_message "INFO" "============ SECURING SNMP ===========" 
    log_message "INFO" "Checking and securing SNMP configuration..."

    CONFIG_FILE="/etc/snmp/snmpd.conf"
    BACKUP_FILE="/etc/snmp/snmpd.conf.bak"

    # Check if SNMP is installed
    if ! command -v snmpd &>/dev/null; then
        log_message "INFO" "SNMP service not found. Skipping remediation."
        return
    fi

    # Backup original configuration
    if [[ -f $CONFIG_FILE && ! -f $BACKUP_FILE ]]; then
        cp $CONFIG_FILE $BACKUP_FILE
        log_message "Backup of SNMP configuration created: $BACKUP_FILE"
    fi

    # Capture existing SNMP community strings
    PUBLIC_RO=$(grep "^rocommunity public" $CONFIG_FILE 2>/dev/null || echo "Not Set")
    PUBLIC_RW=$(grep "^rwcommunity public" $CONFIG_FILE 2>/dev/null || echo "Not Set")

    # Remove insecure public SNMP communities
    sed -i "/^[[:space:]]*rocommunity[[:space:]]\+public/d" $CONFIG_FILE
    sed -i "/^[[:space:]]*rwcommunity[[:space:]]\+public/d" $CONFIG_FILE
    sed -i '/^[^#]*public/s/^/# /' $CONFIG_FILE

    if [[ "$PUBLIC_RO" != "Not Set" ]]; then
        log_message "Removed SNMP public read-only community: $PUBLIC_RO"
    fi

    if [[ "$PUBLIC_RW" != "Not Set" ]]; then
        log_message "Removed SNMP public read-write community: $PUBLIC_RW"
    fi

    # Restart SNMP services if changes were made
    if [[ "$PUBLIC_RO" != "Not Set" || "$PUBLIC_RW" != "Not Set" ]]; then
        systemctl restart snmpd 2>/dev/null && log_message "SNMP service restarted."
        systemctl restart snmptrapd 2>/dev/null && log_message "SNMP trap service restarted (if applicable)."
    else
        log_message "No changes made to SNMP configuration."
    fi

    log_message "Updated" "SNMP security policies successfully applied."
}


# ========== REMEDIATE NTP SYNCHRONIZATION ===================
remediate_ntp() {
    log_message "INFO" "============ NTP SYNCHRONIZATION ===========" 
    log_message "INFO" "Checking and configuring NTP synchronization..."
     if ! command -v chronyd &>/dev/null && ! command -v ntpd &>/dev/null; then
        case $DISTRO in
            "ubuntu"|"debian")
                apt-get update && apt-get install -y chrony
                ;;
            "rhel"|"centos"|"ol")
                yum install -y chrony
                ;;
            "suse")
                zypper install -y chrony
                ;;
            *)
                log_message "ERROR" "Unsupported Linux distribution for NTP installation."
                return
                ;;
        esac
        log_message "INFO" "Installed NTP package."
    fi

    systemctl enable chronyd || systemctl enable chrony
    systemctl start chronyd || systemctl start chrony
    log_message "INFO" "NTP service started and enabled."

    # Wait briefly for chronyd to initialize (e.g., 5 seconds)
    sleep 5

    # Check if chronyd is synchronized
    if ! chronyc tracking &>/dev/null || ! chronyc tracking | grep -q "Leap status\s*:\s*Normal"; then
        log_message "WARN" "NTP is not synchronized. Configuring NTP server..."

        # Backup chrony.conf
        cp /etc/chrony.conf /etc/chrony.conf.bkp.$(date +%F-%T)

        # Comment out existing pool lines
        sed -i '/^pool /s/^/#/' /etc/chrony.conf

        # Determine the server's IP prefix (assuming this is the system's IP)
        SERVER_IP=$(ip a|grep -i "10\."|awk '{print $2}'|awk -F "/" '{print $1}')
        NTP_SERVER=""

        # Map IP prefix to NTP server
        case $SERVER_IP in
            10.230.*)
                NTP_SERVER="10.230.2.200"
                ;;
            10.162.*)
                NTP_SERVER="10.162.8.200"
                ;;
            10.240.*)
                NTP_SERVER="10.240.8.200"
                ;;
            10.154.*)
                NTP_SERVER="10.154.8.200"
                ;;
            *)
                NTP_SERVER="10.230.2.200"  # Default fallback
                log_message "WARN" "Unknown IP prefix ($SERVER_IP), using default NTP server $NTP_SERVER."
                ;;
        esac

        # Add the new server line
        echo "server $NTP_SERVER iburst" >> /etc/chrony.conf

        # Restart chronyd to apply changes
        systemctl restart chronyd
        log_message "INFO" "Updated /etc/chrony.conf with server $NTP_SERVER and restarted chronyd."

        # Wait and recheck synchronization
        sleep 10
        if chronyc tracking &>/dev/null && chronyc tracking | grep -q "Leap status\s*:\s*Normal"; then
            log_message "INFO" "NTP synchronization successful with $NTP_SERVER."
        else
            log_message "ERROR" "NTP synchronization failed after configuration."
        fi
    else
        log_message "INFO" "NTP is already synchronized."
    fi
}

# ====== REMEDIATE PASSWORD ENCRYPTION ==========================
remediate_password_encryption() {
    log_message "INFO" "============ PASSWORD ENCRYPTION POLICY ==========="
    log_message "INFO" "Checking and enforcing password encryption policy..."

    CONFIG_FILE="/etc/login.defs"
    BACKUP_FILE="/etc/login.defs.bak"

    # Backup original configuration before modification
    if [[ -f $CONFIG_FILE && ! -f $BACKUP_FILE ]]; then
        cp $CONFIG_FILE $BACKUP_FILE
        log_message "Backup created: $BACKUP_FILE"
    fi

    # Capture current encryption method
    CURRENT_ENCRYPT_METHOD=$(grep "^ENCRYPT_METHOD" $CONFIG_FILE 2>/dev/null || echo "Not Set")

    # Modify or add ENCRYPT_METHOD in login.defs
    if [[ "$CURRENT_ENCRYPT_METHOD" =~ "ENCRYPT_METHOD" ]]; then
        sed -i "s/^ENCRYPT_METHOD.*/ENCRYPT_METHOD $REQUIRED_ENCRYPT_METHOD/" $CONFIG_FILE
        log_message "Updated" "Modified encryption method: $CURRENT_ENCRYPT_METHOD → ENCRYPT_METHOD $REQUIRED_ENCRYPT_METHOD"
    else
        echo "ENCRYPT_METHOD $REQUIRED_ENCRYPT_METHOD" >> $CONFIG_FILE
        log_message "Updated" "Added encryption method: ENCRYPT_METHOD $REQUIRED_ENCRYPT_METHOD"
    fi

    # Ensure PAM modules use SHA512 encryption for password hashing
    PAM_FILES=("/etc/pam.d/system-auth" "/etc/pam.d/password-auth")
    for PAM_FILE in "${PAM_FILES[@]}"; do
        if [[ -f "$PAM_FILE" ]]; then
            if grep -q "pam_unix.so" "$PAM_FILE"; then
                sed -i "s/^password.*pam_unix.so.*/password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok/" "$PAM_FILE"
                log_message "Updated" "Updated PAM encryption settings in $PAM_FILE to enforce SHA512."
            else
                log_message "INFO" "PAM module pam_unix.so not found in $PAM_FILE, skipping."
            fi
        fi
    done

    log_message "Updated" "Password encryption policies successfully applied."
}

# ====== MAIN FUNCTION =====================
main() {
    log_message "......Compliance Remediation script started on $(hostname) ....."

    # Check if the script is running as root
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR: This script must be run as root. Exiting."
        exit 1
    fi

    # Track start time
    START_TIME=$(date +%s)


    detect_distro

    # Execute remediation functions with error handling

    remediate_log_retention

    remediate_screen_lock
	if [[ "$DISTRO" =~ "ubuntu" ]]; then
    log_message "INFO" "================ ACCOUNT LOCKOUT POLICY ================"
    log_message "INFO" "Checking and applying Account lockout settings ..."
remediate_lockout_ubuntu
fi
if [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ] || [ "$DISTRO" = "ol" ]; then
    if ! grep -q "pam_faillock.so" /etc/pam.d/sshd; then
    log_message "INFO" "================ ACCOUNT LOCKOUT POLICY ================"
    log_message "INFO" "Checking and applying Account lockout settings ..."
        echo "pam_faillock.so not found in /etc/pam.d/sshd. Running remediation..."
        remediate_lockout_rhel
    else
    log_message "INFO" "================ ACCOUNT LOCKOUT POLICY ================"
    log_message "INFO" "Checking and applying Account lockout settings ..."
        echo "pam_faillock.so already present in /etc/pam.d/sshd. No remediation needed."
    fi
fi

    remediate_snmp

    remediate_ntp

    remediate_password_encryption

    log_message "FINAL-INFO" "Compliance remediation script completed."
	
	log_message "................... THANK YOU ........................."

}

# Execute script
main
