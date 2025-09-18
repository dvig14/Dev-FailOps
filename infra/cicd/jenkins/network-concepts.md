## Understand Some terms which gonna use further
### Host-only Network

* Think of this as a **private cable** directly between the **host computer** and the **VM**.
* The VM gets an IP from a **special subnet** (by default `192.168.56.0/24`).
* You can reach the VM from the host machine (e.g., SSH/HTTP) and also can talk to other VMs on same host, but **not from the internet** or other devices on your LAN.

📌 Example:

* Host (Windows) gets `192.168.56.1`.
* VM gets `192.168.56.13`.
* Your (host) and other VMs on same host can SSH/HTTP VM at `192.168.56.13`.

<br>

### Bridged Network

* This makes the VM look like a **real computer on your actual LAN**.
* It “bridges” the VM’s virtual NIC to your **physical NIC** (WiFi/Ethernet).
* VM gets an IP in the same range as your real network.

📌 Example:

* Your WiFi = `192.168.1.0/24`.
* Laptop (host) = `192.168.1.100`.
* VM (bridged) = `192.168.1.50`.
* Any device on LAN (even your phone) can reach that VM.

<br>

### Subnet

* A **subnet** is a "room" inside the bigger house of IP addresses.
* Example: `192.168.56.0/24` means → all devices with IPs `192.168.56.1` to `192.168.56.254` are in **one room** (subnet) 

> [More About Subnet](https://www.cloudflare.com/en-gb/learning/network-layer/what-is-a-subnet/)

<br>

### 🔌 What happens on one host

On your **Windows host machine**, VirtualBox creates **network adapters** (like extra NICs).

* **Host-only adapter**: Creates a private subnet between host and VMs. Default = `192.168.56.0/24`.
* **Bridged adapter**: Connects VM directly to your real physical network (LAN/WiFi). Usually that subnet = `192.168.0.0/24` or `192.168.1.0/24` (whatever your router gives).

---

### ⚠️ Error During Infra Provisioning

```text
The specified host network collides with a non-hostonly network!
Bridged Network Address: '192.168.56.0'
Host-only Network 'enp0s8': '192.168.56.0'
```

---

### 🔍 Flow of Setup

1. **Host (Windows)** spins up the **Jenkins VM** with **host-only IP**:

   ```
   192.168.56.13
   ```
2. Inside this **Jenkins VM**, the pipeline provisions the **App VM** with **host-only IP**:

   ```
   192.168.56.11
   ```
3. Expected outcome: App VM and Jenkins VM communicate over the same host-only network.

--- 

### ❗ Problem

* The **Jenkins VM host-only IP** `192.168.56.13` gets considered for **bridge networking**, even though bridging wasn’t explicitly enabled.
* This happens because when **VirtualBox is installed inside Jenkins VM**, it automatically creates **network adapters**.
* These adapters include a **bridge adapter** that considers the NICs (NAT/Host-only) of the host machine, which in this case is the **Jenkins VM** itself.
* When the pipeline spins up the **App VM** with **host-only IP** `192.168.56.11` (for communication with Jenkins VM):

  * A **subnet collision** occurs since both Jenkins VM (`192.168.56.13`) and App VM (`192.168.56.11`) fall under the same subnet `192.168.56.0/24`.
* Two adapters cannot use the **same subnet**, as this creates confusion about where packets should be routed.
* As a result, **App VM creation fails** and the provisioning process throws the **collision error**.

---

### 📷 References

* Jenkins VM Bridged Interfaces: [Screenshot](./assets/jenkins-vbox.png)
  *(Lists physical NICs on Jenkins VM that VirtualBox can bridge to)*
* On **Windows Host**, this problem does not occur because:

  * **Bridged adapters** and **Host-only adapters** are on **different subnets**.
  * [Windows Bridgedifs](./assets/win-vbox_bridge.png)
  * [Windows Host-onlyifs](./assets/win-vbox_host.png)

<br>

## 2 ways to fix above issue so that host machine (windows/linux) can also communicate with app vm which runs inside jenkins (guest vm)

### 1. Make the App VM join the 192.168.56.x network (bridged inside Jenkins)

Instead of giving host-only (private ip) to app vm we can use bridge network (public ip)

#### [enp0s8](./assets/jenkins-vbox.png)

* IP: `192.168.56.13`
* That’s the **Host-Only Adapter** network VirtualBox created.
* Used mainly so **host ↔ VM communication** is possible, but not outside LAN/Internet.
* If we bridge app vm to this, then it falls under same subnet as host machine's (windows/linux) [host-only adapter](./assets/win-vbox_host.png)
* By this app vm can easily communicate with jenkins vm as well as host machine without going through router/gateway

<br>

#### Vagrantfile setup for bridged network

Here’s a minimal example:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "app-vm"
  config.vm.network "public_network", ip: "192.168.56.11", bridge: "enp0s8"
end
```

#### Key point 

* **Bridging puts the app vm on the same subnet** as the Jenkins host-only NIC.
* App VM = 192.168.56.11
* Jenkins Host-only = 192.168.56.13
* Windows NIC (Host) = 192.168.56.1
* All in same subnet → direct ping, SSH, HTTP works.    

<br>

### 2. Keep App VM on 57.x and make Jenkins a router between 56.x ↔ 57.x (In our case we gonna do this)

* Host Machine (Windows/Linux): `192.168.56.1`
* Jenkins VM: `192.168.56.13` (interface towards Host Machine) and `192.168.57.1` (interface towards App VM)
* App VM: `192.168.57.11`
* Traffic from Host (Windows/Linux) destined to `192.168.57.11` doesn’t belong to the same subnet.
* Windows doesn’t know **how to reach 57.x** by default.
* Jenkins VM can act as a **router** to forward packets between the 56.x and 57.x networks.

### 1. Enable routing on Jenkins VM
```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-ipforward.conf
sudo sysctl -p /etc/sysctl.d/99-ipforward.conf
```

* **What it does:** Makes IP forwarding **persistent across reboots**.
* `/etc/sysctl.d/99-ipforward.conf` sets the config permanently.
* `sysctl -p` applies the changes immediately.
* `net.ipv4.ip_forward=1`
  * net → namespace for kernel network stack.
  * ipv4 → setting applies to IPv4 (there’s also ipv6.conf.all.forwarding for IPv6).
  * ip_forward → toggle for whether this Linux machine can forward packets not destined for itself.
  * =1 → enable forwarding. (0 = disable)

<br>

### 2. Enable NAT on Jenkins VM
```bash
sudo iptables -t nat -A POSTROUTING -s 192.168.56.0/24 -o vboxnet0 -j MASQUERADE
```

* **What this does:**
* `-t nat` → use the NAT table.
* `POSTROUTING` → rewrite packets after routing.
* `-s 192.168.56.0/24` → traffic from Windows subnet.
* `-o vboxnet0` → going out to the App subnet.
* `MASQUERADE` → replace Windows source IP (192.168.56.x) with Jenkins’ App-side IP (192.168.57.1).

📷 [Jenkins VM Hostonlyifs Once App Vm Spins Up](./assets/hostifs-jenkins.png)

**Verify:**
```bash
sudo iptables -t nat -L -n -v

## output
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      vboxnet0  192.168.56.0/24      0.0.0.0/0
```

**To Make it persistent**
```bash
sudo iptables-save | sudo tee /etc/iptables.rules

## See Path that will use in systemd in ExecStart
which iptables-restore

cat << EOF | sudo tee /etc/systemd/system/iptables-restore.service
[Unit]
Description=Restore iptables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "<Which-Iptables-Restore-Path-Output> < /etc/iptables.rules"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable iptables-restore.service
sudo systemctl start iptables-restore.service
```

<br>

### 3. Route on host machine 

> This Run On Host Machine Not inside Jenkins VM

* Windows: Run Cmd prompt as Admin
```powershell
route -p add 192.168.57.0 mask 255.255.255.0 192.168.56.13 if <InterfaceNumber>
```

* Here we are adding to routing table that all req for subnet 57.x goes from router/gateway jenkins vm host-only ip `192.168.56.13` with interface host machine NIC `192.168.56.1`
* `<InterfaceNumber>` : this is for Host machine Nic (e.g. 4, 10) You can check yours run route print and on which interface num host-only adapter with `192.168.56.1` set
```
route -p add 192.168.57.0 mask 255.255.255.0 192.168.56.13 if 4
```

**Verify:**
```powershell
route print
```

**output**
```powershell
Interface List
  9...f8 a9 63 6f e7 1d ......Realtek PCIe GBE Family Controller
  4...0a 00 27 00 00 04 ......VirtualBox Host-Only Ethernet Adapter
===========================================================================

IPv4 Route Table
===========================================================================
Active Routes:
Network Destination       Netmask          Gateway       Interface    Metric
    192.168.57.0    255.255.255.0    192.168.56.13     192.168.56.1     26
===========================================================================
Persistent Routes:
  Network Address        Netmask    Gateway Address   Metric
    192.168.57.0    255.255.255.0    192.168.56.13       1
===========================================================================
```

* Linux:
```bash
sudo ip route add 192.168.57.0/24 via 192.168.56.13
```
* `192.168.57.0/24` → your App VM subnet
* `via 192.168.56.13` → Jenkins VM IP (the “gateway” that knows how to reach App VM)

Verify:
```bash
ip route show
```

<br>

### Full Flow

**1.** As we set route on host machine so when we browse app vm `http://192.168.57.11` on host machine (windows/linux) it send req to jenkins vm ip `192.168.56.13` which act as gateway as both host machine `192.168.56.1` and jenkins vm are on same `56.x` so they can communicate

<br>

**2.** When jenkins vm receive this req at NIC (`enp0s8 - 192.168.56.13`) with destination ip `192.168.57.11`. 
  - If the destination IP matches any of its own interfaces, it treats the packet as “for me” → passes it to local applications.
  - If the destination IP doesn’t match any interface, it considers forwarding as we already enabled that `net.ipv4.ip_forward=1`

<br>

**3.** So here it will use routing table `ip route` to see which interface to forward packets:
```
192.168.57.0/24 dev vboxnet0  src 192.168.57.1
192.168.56.0/24 dev enp0s8   src 192.168.56.13
```
  - Linux looks at routing table → sees that 192.168.57.0/24 is via vboxnet0.
  - Packet is sent out through vboxnet0 NIC to App VM.

<br>

**4.** Here App VM will see req destined to `192.168.57.11` → its own ip
- If nat not enabled app vm will see host machine ip (ie `192.168.56.1`) and as not same subnet it doesn’t know how to reach it → reply gets lost.
- But as `NAT is enabled` so jenkins:
  - Rewrites source IP from `192.168.56.1` → `192.168.57.1` (Jenkins interface towards App VM).
  - Records this mapping in the NAT connection table:
``` 
  | Original Src | Original Dst  | NAT Src      | NAT Dst       | State       |
  | ------------ | ------------- | ------------ | ------------- | ----------- |
  | 192.168.56.1 | 192.168.57.11 | 192.168.57.1 | 192.168.57.11 | ESTABLISHED |
```
- App VM sends reply back to `192.168.57.1` it has no idea about the original host (Windows/Linux).

<br>

**5.** Jenkins receives packet from App VM:
- Source IP: `192.168.57.11`
- Destination IP: `192.168.57.1`
- NAT looks up its connection table → sees that this response belongs to the original request from `192.168.56.1`.
- NAT rewrites destination IP back from `192.168.57.1` → `192.168.56.1`.

<br>

**6.** So here it will again use routing table :
```
192.168.57.0/24 dev vboxnet0  src 192.168.57.1
192.168.56.0/24 dev enp0s8   src 192.168.56.13
```
  - Destination `192.168.56.1` → route via enp0s8 (192.168.56.13)
  - Packet is sent out `192.168.56.13` → Windows receives it
