# macOS Hardening and Automation Guide for Non-MDM Users

This document explains what can and cannot be automated on macOS when you are **not** using Mobile Device Management (MDM). It is designed for individuals who manage their own Macs, whether you have one machine that you reinstall often, or multiple machines you want to configure identically with scripts.

---

## 1. What Is MDM and Why It Matters

- **Mobile Device Management (MDM)**: Apple’s enterprise framework that allows organizations (businesses, schools) to push and enforce system-wide policies on Macs and iOS devices. Examples: Jamf, Intune, Kandji, Mosyle.
- **MDM-enrolled Mac**: A machine registered with such a service. It can accept and enforce special payloads (configuration profiles) that ordinary users cannot apply by themselves. Example: disabling Location Services globally, or blocking access to system apps.
- **Non-MDM Mac**: A personal machine, not enrolled in any MDM service. This is the case for almost all individual users who bought a Mac directly from Apple or a retailer.

**Key difference:**  
On an MDM Mac, certain privacy/security controls can be automated and enforced. On a non-MDM Mac, the same controls are ignored unless you set them manually through the graphical interface.

---

## 2. Transparency, Consent, and Control (TCC)

- **TCC** = *Transparency, Consent, and Control*.  
- This is Apple’s framework that protects sensitive resources (location, camera, microphone, contacts, notifications).  
- On non-MDM Macs, TCC always requires **explicit user interaction**: the user must click “Allow” or “Don’t Allow” in System Settings when an app requests access.

**Why this matters:**  
- You cannot automate toggling these settings by script on a personal Mac.  
- Apple enforces this to prevent malware from secretly turning services on or off.  
- The side effect: it also prevents you, the owner, from fully automating those controls.

---

## 3. The Automation Hierarchy for Non-MDM Users

Think of setup as a ladder with two main rungs:

### Rung A: What You Can Automate (80–90%)

These settings can be applied reliably with shell scripts:

- **FileVault (full-disk encryption)**  
  - Automatable with `fdesetup enable -defer` (requires SecureToken user).
- **Firewall (network connection filter)**  
  - Automatable with `socketfilterfw` commands.
- **Gatekeeper (only allow signed applications)**  
  - Automatable with `spctl --master-enable`.
- **Automatic updates**  
  - Automatable with `defaults write` to `/Library/Preferences/com.apple.SoftwareUpdate` and `/Library/Preferences/com.apple.commerce`.
- **Diagnostics & analytics opt-out**  
  - Automatable with `defaults write /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit -bool false`.
- **Most Finder, Dock, Safari, and app-specific preferences**  
  - Automatable with `defaults write`.

These can be bundled into one script and re-run after each reinstall or on multiple machines for consistency.

### Rung B: What Requires Manual User Interaction (10–20%)

These settings are **protected by TCC** and cannot be scripted on a non-MDM Mac:

- **Location Services (GPS, Wi-Fi, Bluetooth location data)**  
  - Must be toggled manually in *System Settings → Privacy & Security → Location Services*.
- **Notifications (per app)**  
  - Must be configured manually in *System Settings → Notifications*.
- **Camera and Microphone access (per app)**  
  - Must be set manually the first time an app requests access, or in *System Settings → Privacy & Security → Camera/Microphone*.
- **Other TCC-protected resources**  
  - Examples: Contacts, Calendar, Photos, Screen Recording.

Apple deliberately blocks scripts from touching these without MDM.

---

## 4. Practical Workflow for Repeatable Setup

### Step 1: Automate the Majority
- Write a deployment script that:
  - Enables FileVault, Firewall, Gatekeeper.
  - Configures automatic updates.
  - Disables diagnostics submission.
  - Applies all your app preferences.
- Run this script on every new or freshly reinstalled Mac.

### Step 2: Manual Privacy Actions
After running the script, **you must manually do**:

1. Turn **off Location Services** in *System Settings*.  
2. Configure **Notifications** per app (or silence with Focus mode if desired).  
3. Deny or allow **Camera and Microphone access** the first time an app asks.  
4. Review other privacy panes (Contacts, Photos, Screen Recording).

### Step 3: Verify
- Check FileVault is “On” in *System Settings → Privacy & Security*.  
- Check Firewall is “On” in *System Settings → Network → Firewall*.  
- Run `spctl --status` to verify Gatekeeper.  
- Run `softwareupdate --schedule` to confirm automatic updates are active.

---

## 5. Summary

- **MDM-enrolled Macs**: Organizations can enforce everything, including Location Services and Notifications.  
- **Non-MDM Macs (personal)**: You can automate 80–90% of security/privacy settings with shell scripts, but must accept **manual user interaction** for TCC-protected items.  
- **The trade-off**: Apple blocks automation of sensitive privacy controls to stop malware, but this also limits your ability to fully script a hardened personal Mac.  
- **Best practice**: Script what you can, make a checklist for the manual steps, and run through that checklist after each deployment.

---
