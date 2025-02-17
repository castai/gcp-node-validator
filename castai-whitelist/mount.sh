echo "# Overriding kubelet certificate directory mount"
sed -i 's, echo "Mounting /var/lib/kubelet/pki on tmpfs",#&,' /home/kubernetes/bin/configure-helper.sh
sed -i 's, mount -t tmpfs tmpfs /var/lib/kubelet/pki,#&,' /home/kubernetes/bin/configure-helper.sh
