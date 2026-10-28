#!/usr/bin/env bash
# Dashboard menu: detection -> options, steps, generated manifests per option,
# the pod values, secrets and labelled cleanup. kubectl is a stub; nothing here
# talks to a cluster.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../public/kwatch.sh
source "$ROOT/public/kwatch.sh"
set +e

FAILS=0
ok() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILS=$((FAILS + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else fail "$1: expected [$3] got [$2]"; fi; }
has() { if grep -Fq -- "$3" <<<"$2"; then ok "$1"; else fail "$1: missing [$3]"; fi; }
hasnt() { if grep -Fq -- "$3" <<<"$2"; then fail "$1: unexpected [$3]"; else ok "$1"; fi; }

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
# Fixtures, set per test.
F_CLASSES="" F_PROVIDER="" F_NODES="" F_CRDS="" F_APIS="" F_GATEWAYS="" F_ISSUERS=""
F_OWNER="installer" F_SECRET_EXISTS=no

deployment_name() { printf 'kwatch'; }
kubectl() {
  printf '%s\n' "$*" >>"$LOG"
  case "$*" in
    "get ingressclass "*) printf '%s' "$F_CLASSES" ;;
    "get crd "*) case " $F_CRDS " in *" ${3} "*) printf 'crd/%s\n' "$3" ;; *) return 1 ;; esac ;;
    "api-versions") printf '%s' "$F_APIS" ;;
    "get nodes -o jsonpath={.items[0].spec.providerID}") printf '%s' "$F_PROVIDER" ;;
    "get nodes -o jsonpath="*) printf '%s' "$F_NODES" ;;
    "get gateway.gateway.networking.k8s.io "*) printf '%s' "$F_GATEWAYS" ;;
    "get clusterissuers.cert-manager.io "*) printf '%s' "$F_ISSUERS" ;;
    *"get deployment kwatch -o go-template"*) printf 'app=kwatch\n' ;;
    *"get secret kwatch-dashboard -o name"*|*"get secret kwatch-dashboard") [ "$F_SECRET_EXISTS" = yes ] ;;
    *"jsonpath={.metadata.labels.app"*) printf '%s' "$F_OWNER" ;;
    *) return 0 ;;
  esac
}

reset_fixtures() {
  F_CLASSES="" F_PROVIDER="" F_NODES="" F_CRDS="" F_APIS="" F_GATEWAYS="" F_ISSUERS=""
  dash_reset_answers
}

detect() { dash_detect >/dev/null 2>&1; dash_options; }

# ---- detection -> options ---------------------------------------------------
reset_fixtures; detect
eq "bare cluster options" "$DASH_OPTIONS" "1 7 8"
eq "bare cluster no recommendation" "$DASH_RECOMMENDED" ""

reset_fixtures
F_CLASSES=$'nginx|k8s.io/ingress-nginx|true\n'; detect
eq "default class shows ingress" "$DASH_OPTIONS" "1 2 7 8"
eq "default class recommends ingress" "$DASH_RECOMMENDED" "2"

reset_fixtures
F_CLASSES=$'nginx|k8s.io/ingress-nginx|\ntraefik|traefik.io/ingress-controller|\n'; detect
eq "two classes, none default: not recommended" "$DASH_RECOMMENDED" ""
eq "found types" "$(dash_found_types)" "nginx, Traefik"

reset_fixtures
F_APIS=$'route.openshift.io/v1\n'
F_CLASSES=$'openshift-default|openshift.io/ingress-to-route|true\n'; detect
eq "openshift recommended first" "$DASH_RECOMMENDED" "4"
has "openshift options" " $DASH_OPTIONS " " 4 "

reset_fixtures
F_PROVIDER="aws:///eu-west-1a/i-0abc"
F_NODES=$'n1||10.0.0.1\n'; detect
eq "aws: load balancer, no NodePort" "$DASH_OPTIONS" "1 5 7 8"
eq "aws recommends load balancer" "$DASH_RECOMMENDED" "5"
eq "aws region" "$DASH_D_REGION" "eu-west-1"

reset_fixtures
F_NODES=$'n1||192.168.1.5\n'; detect
eq "bare metal with node address: NodePort" "$DASH_OPTIONS" "1 6 7 8"

reset_fixtures
F_CRDS="gateways.gateway.networking.k8s.io"
F_GATEWAYS=$'gateways|shared-gw|HTTPS,|All,|*.example.com,\ngateways|plain-gw|HTTP,|All,|\n'; detect
eq "gateway with https listener" "$DASH_OPTIONS" "1 3 7 8"
eq "gateway recommended" "$DASH_RECOMMENDED" "3"
eq "gateway without https is hidden and counted" "$DASH_D_GW_HIDDEN" "1"

reset_fixtures
F_CRDS="certificates.cert-manager.io"
F_ISSUERS=$'selfsigned|ClusterIssuer||||{}\nletsencrypt-prod|ClusterIssuer|https://acme||\n'; detect
dash_pick_issuer; eq "letsencrypt-prod preferred, selfsigned ignored" "$DASH_ISSUER" "letsencrypt-prod"
F_ISSUERS=$'a|ClusterIssuer|https://acme||\nb|ClusterIssuer||ca-secret|\n'; detect
dash_pick_issuer; eq "several issuers: ask" "$?" "2"

eq "controller nginx" "$(dash_controller_type k8s.io/ingress-nginx)" nginx
eq "controller alb" "$(dash_controller_type ingress.k8s.aws/alb)" alb
eq "controller unknown" "$(dash_controller_type example.com/x)" other

# ---- validation ----------------------------------------------------------------
dash_normalize_address "  HTTPS://Kwatch.Example.com/ " && eq "address normalised" "$DASH_ADDR_CLEAN" "kwatch.example.com"
dash_normalize_address "http://x.example.com"; has "http refused" "$DASH_ADDR_ERR" "only shares the dashboard over https"
dash_normalize_address "203.0.113.5"; has "ip refused" "$DASH_ADDR_ERR" "Use a name, not an IP address"
dash_normalize_address "a.example.com:8443"; has "port refused" "$DASH_ADDR_ERR" "Type just the address"
dash_normalize_address "*.example.com"; has "wildcard refused" "$DASH_ADDR_ERR" "Type just the address"
dash_normalize_address "nodots"; has "bad name" "$DASH_ADDR_ERR" "doesn't look like an address"
dash_parse_ips "203.0.113.0/24, 198.51.100.7" && eq "ips parsed" "$DASH_IPS_CLEAN" "203.0.113.0/24,198.51.100.7"
dash_parse_ips "10.0.0.5" && eq "private flagged" "$DASH_IPS_ALL_PRIVATE" "true"
dash_parse_ips "nope"; has "bad ip" "$DASH_IPS_ERR" "isn't an IP address or range"
dash_parse_ips "0.0.0.0/0"; eq "everyone code" "$?" "3"
dash_valid_arn "arn:aws:acm:eu-west-1:123456789012:certificate/abcd-12" && ok "arn ok" || fail "arn ok"
dash_valid_arn "arn:aws:s3:::x" && fail "arn bad" || ok "arn bad"
dash_ip_in_range 192.168.1.245 192.168.1.240-192.168.1.250 && ok "range in" || fail "range in"
dash_ip_in_range 192.168.2.1 192.168.1.240-192.168.1.250 && fail "range out" || ok "range out"
dash_ip_in_range 10.0.5.9 10.0.5.0/24 && ok "cidr in" || fail "cidr in"

# ---- steps per option (7c.5) ---------------------------------------------------
st() { DASH_WAY=$1; DASH_CTYPE=${2:-}; dash_steps; }
eq "steps nginx" "$(st ingress nginx)" "class addr tls ips"
eq "steps contour" "$(st ingress contour)" "class addr tls"
eq "steps alb" "$(st ingress alb)" "class addr alb_scheme alb_arn ips"
eq "steps gke" "$(st ingress gke)" "class addr gke_notice gke_ip"
eq "steps agic" "$(st ingress agic)" "class addr agic_pub tls"
eq "steps tailscale" "$(st ingress tailscale)" "class ts_name"
eq "steps ngrok" "$(st ingress ngrok)" "class ngrok_domain"
eq "steps gateway" "$(st gateway)" "gw_pick addr"
eq "steps route" "$(st route)" "addr tls ips"
eq "steps lb" "$(st lb)" "lb_who lb_pool lb_ip addr tls ips"
eq "steps nodeport" "$(st nodeport)" "np_port addr tls"
eq "steps proxy" "$(st proxy)" "addr proxy_gate"
eq "steps service" "$(st service)" "addr tls"

# ---- manifests per option --------------------------------------------------------
gen() { dash_manifests 2>/dev/null; }

reset_fixtures
DASH_WAY=ingress DASH_CTYPE=nginx DASH_CLASS=nginx DASH_ADDR=kwatch.example.com
DASH_CERT=auto DASH_ISSUER=letsencrypt-prod DASH_ISSUER_KIND=ClusterIssuer
DASH_TLS_SECRET=kwatch-dashboard-tls DASH_IPS="203.0.113.0/24"
m=$(gen)
has "nginx ingress" "$m" "kind: Ingress"
has "nginx label" "$m" "app.kwatch.dev/managed-by: installer"
has "nginx whitelist" "$m" 'nginx.ingress.kubernetes.io/whitelist-source-range: "203.0.113.0/24"'
has "nginx tls secret" "$m" "secretName: kwatch-dashboard-tls"
has "nginx certificate" "$m" "kind: Certificate"
has "nginx issuer" "$m" "name: letsencrypt-prod"
has "base service clusterip" "$m" "type: ClusterIP"
has "base service port name" "$m" "- name: dashboard"
eq "nginx values" "$(dash_values)" "shared true "
eq "nginx plan" "$(dash_objects_csv)" "ingress/kwatch-dashboard,certificate/kwatch-dashboard-tls"

DASH_CTYPE=traefik DASH_CLASS=traefik; m=$(gen)
has "traefik entrypoint" "$m" "router.entrypoints"
has "traefik allowlist" "$m" "kind: Middleware"
has "traefik sourceRange" "$m" "- 203.0.113.0/24"

DASH_CTYPE=haproxy DASH_CLASS=haproxy; m=$(gen)
has "haproxy allowlist" "$m" "allowlist-source-range"
DASH_CTYPE=haproxytech; m=$(gen)
has "haproxytech allowlist" "$m" "haproxy.org/allow-list"

DASH_IPS="" DASH_CTYPE=contour; m=$(gen)
has "contour redirect" "$m" "force-ssl-redirect"
DASH_CTYPE=kong; m=$(gen)
has "kong https" "$m" "konghq.com/protocols"
DASH_CTYPE=other; m=$(gen)
hasnt "other has no annotations block" "$m" "annotations:"$'\n'"    nginx"

DASH_CTYPE=alb DASH_CLASS=alb DASH_ALB_INTERNAL=false DASH_CERT=acm
DASH_ACM_ARN="arn:aws:acm:eu-west-1:123456789012:certificate/abcd" DASH_IPS="198.51.100.7"; m=$(gen)
has "alb scheme" "$m" '"internet-facing"'
has "alb arn" "$m" "certificate-arn"
has "alb backend https" "$m" 'backend-protocol: "HTTPS"'
has "alb inbound cidrs" "$m" 'inbound-cidrs: "198.51.100.7"'
hasnt "alb no cert-manager" "$m" "kind: Certificate"
eq "alb values (backend tls)" "$(dash_values)" "shared false kwatch-dashboard-backend-tls"
eq "alb plan" "$(dash_objects_csv)" "ingress/kwatch-dashboard,secret/kwatch-dashboard-backend-tls"

DASH_CTYPE=gke DASH_CERT=google DASH_IPS="" DASH_GKE_IP=kwatch-ip; m=$(gen)
has "gke managed cert" "$m" "kind: ManagedCertificate"
has "gke frontend config" "$m" "kind: FrontendConfig"
has "gke static ip" "$m" "global-static-ip-name"
has "gke app protocol on service" "$m" "cloud.google.com/app-protocols"

DASH_CTYPE=agic DASH_CLASS=azure-application-gateway DASH_AGIC_PRIVATE=true DASH_CERT=self DASH_TLS_SECRET=kwatch-dashboard-tls; m=$(gen)
has "agic private" "$m" 'use-private-ip: "true"'
has "agic backend https" "$m" 'backend-protocol: "https"'
has "agic tls" "$m" "secretName: kwatch-dashboard-tls"

DASH_CTYPE=tailscale DASH_CLASS=tailscale DASH_TS_NAME=kwatch; m=$(gen)
has "tailscale class" "$m" "ingressClassName: tailscale"
has "tailscale host" "$m" "- kwatch"
eq "tailscale values" "$(dash_values)" "shared true "
DASH_CTYPE=ngrok DASH_CLASS=ngrok DASH_ADDR=kwatch.ngrok.app; m=$(gen)
has "ngrok host" "$m" "host: kwatch.ngrok.app"

reset_fixtures
DASH_WAY=gateway DASH_GW_NS=gateways DASH_GW_NAME=shared-gw DASH_ADDR=kwatch.example.com; m=$(gen)
has "httproute" "$m" "kind: HTTPRoute"
has "httproute parent" "$m" "namespace: gateways"
eq "gateway values" "$(dash_values)" "shared true "
DASH_WAY=istio; m=$(gen)
has "virtualservice" "$m" "kind: VirtualService"
has "virtualservice gateway" "$m" "- gateways/shared-gw"

reset_fixtures
DASH_WAY=route DASH_ADDR=kwatch-dashboard-kwatch.apps.example.com DASH_CERT=handled DASH_IPS="198.51.100.7"; m=$(gen)
has "route kind" "$m" "kind: Route"
has "route edge" "$m" "termination: edge"
has "route ip whitelist" "$m" "ip_whitelist"

reset_fixtures
DASH_WAY=lb DASH_D_CLOUD=aws DASH_D_LB_KIND=cloud DASH_LB_INTERNAL=true DASH_ADDR=kwatch.example.com
DASH_CERT=auto DASH_ISSUER=le DASH_ISSUER_KIND=ClusterIssuer DASH_TLS_SECRET=kwatch-dashboard-tls DASH_IPS="203.0.113.0/24"; m=$(gen)
has "lb service" "$m" "type: LoadBalancer"
has "lb name" "$m" "name: kwatch-dashboard-lb"
has "lb internal" "$m" "aws-load-balancer-internal"
has "lb source ranges" "$m" "loadBalancerSourceRanges:"
has "lb https port" "$m" "port: 443"
eq "lb values" "$(dash_values)" "shared false kwatch-dashboard-tls"
DASH_D_CLOUD=none DASH_D_LB_KIND=metallb DASH_LB_POOL=office-pool DASH_LB_IP=10.0.5.12; m=$(gen)
has "metallb pool" "$m" "metallb.universe.tf/address-pool"
has "metallb ip" "$m" "metallb.universe.tf/loadBalancerIPs"

reset_fixtures
DASH_WAY=nodeport DASH_NODEPORT=30443 DASH_CERT=self DASH_TLS_SECRET=kwatch-dashboard-tls DASH_ADDR_IP=true; m=$(gen)
has "nodeport service" "$m" "type: NodePort"
has "nodeport port" "$m" "nodePort: 30443"
eq "nodeport plan" "$(dash_objects_csv)" "service/kwatch-dashboard-nodeport,secret/kwatch-dashboard-tls"

reset_fixtures
DASH_WAY=proxy DASH_ADDR=kwatch.example.com DASH_CERT=none; m=$(gen)
hasnt "proxy creates no exposure" "$m" "kind: Ingress"
eq "proxy plan is empty" "$(dash_objects_csv)" ""
eq "proxy values" "$(dash_values)" "shared true "

reset_fixtures
DASH_WAY=service DASH_ADDR=kwatch.example.com DASH_CERT=own DASH_TLS_SECRET=corp-tls; m=$(gen)
eq "service only has just the Service" "$(grep -c '^kind:' <<<"$m")" "1"
eq "service-only values" "$(dash_values)" "shared false corp-tls"

# NetworkPolicy peers only when a policy exists.
reset_fixtures
DASH_NETPOL=true DASH_WAY=lb DASH_IPS="203.0.113.0/24" DASH_D_LB_KIND=metallb; m=$(gen)
has "networkpolicy created" "$m" "kind: NetworkPolicy"
has "networkpolicy ipblock" "$m" "cidr: 203.0.113.0/24"
DASH_NETPOL=false

# ---- confirm text -------------------------------------------------------------------
reset_fixtures
DASH_WAY=ingress DASH_CTYPE=nginx DASH_CLASS=nginx DASH_ADDR=kwatch.example.com DASH_CERT=auto
DASH_ISSUER=letsencrypt-prod DASH_TLS_SECRET=kwatch-dashboard-tls DASH_IPS="203.0.113.0/24"
c=$(dash_confirm_text)
has "confirm title" "$c" "Share the dashboard at https://kwatch.example.com"
has "confirm way" "$c" 'Ingress (nginx, class "nginx")'
has "confirm who" "$c" "Only 203.0.113.0/24, with the password"
has "confirm sign-in" "$c" "Password; plain http is refused"
has "confirm creates" "$c" "an Ingress named kwatch-dashboard"
has "confirm certificate object" "$c" "a Certificate named kwatch-dashboard-tls"

# ---- pod patch is valid JSON ----------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  for args in "kwatch local false " "kwatch shared true " "kwatch shared false kwatch-dashboard-tls" "kwatch off false "; do
    # shellcheck disable=SC2086
    set -- $args
    p=$(dash_deployment_patch "$1" "$2" "$3" "${4:-}")
    if printf '%s' "$p" | python3 -m json.tool >/dev/null 2>&1; then ok "patch json: $args"; else fail "patch json: $args"; fi
  done
fi
p=$(dash_deployment_patch kwatch shared false kwatch-dashboard-tls)
has "patch tls cert" "$p" "KWATCH_DASHBOARD_TLS_CERT"
has "patch volume" "$p" '"secretName":"kwatch-dashboard-tls"'
p=$(dash_deployment_patch kwatch local false "")
has "patch local mode" "$p" '"value":"local"'

# ---- secret: created once, never pre-created over an existing one, no argv password
: >"$LOG"; F_SECRET_EXISTS=yes
dash_ensure_secret
hasnt "existing secret is kept" "$(cat "$LOG")" "create secret"
: >"$LOG"; F_SECRET_EXISTS=no
dash_ensure_secret
has "missing secret created" "$(cat "$LOG")" "create secret generic kwatch-dashboard --from-file=password="
pw=$(dash_new_password)
if [[ "$pw" =~ ^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}(-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}){3}$ ]]; then ok "password format"; else fail "password format: $pw"; fi
hasnt "password never on a command line" "$(cat "$LOG")" "$pw"

# ---- only labelled objects are deleted --------------------------------------------------
: >"$LOG"; F_OWNER=""
dash_delete_if_ours ingress kwatch-dashboard
hasnt "unlabelled object kept" "$(cat "$LOG")" "delete ingress"
: >"$LOG"; F_OWNER="installer"
dash_delete_if_ours ingress kwatch-dashboard
has "labelled object deleted" "$(cat "$LOG")" "delete ingress kwatch-dashboard"

# ---- menu behaviour ---------------------------------------------------------------------
DASH_STATE=off; eq "caption off" "$(dash_state_text)" "off"
DASH_STATE=local; eq "caption local" "$(dash_state_text)" "on, local only"
DASH_STATE=shared DASH_STATE_ADDR=https://kwatch.example.com; eq "caption shared" "$(dash_state_text)" "shared at https://kwatch.example.com"
DASH_STATE_ADDR=""; eq "caption shared unknown address" "$(dash_state_text)" "shared at your own address"
DASH_STATE=unknown; eq "caption unknown" "$(dash_state_text)" "unknown"

out=$(dash_share_flow 2>&1 </dev/null)
has "non-interactive share refused" "$out" "Sharing needs a terminal to ask you a few questions. Run the installer in a terminal."

out=$(NO_COLOR=1 LANG=C dash_e 🌐 Ingress)
eq "emoji dropped without UTF-8 under NO_COLOR" "$out" "Ingress"
out=$(TERM=xterm dash_e 🌐 Ingress)
has "emoji kept normally" "$out" "🌐"

# ---- questions end to end with piped answers (plain, non-tty prompts) ------------
reset_fixtures
F_CLASSES=$'nginx|k8s.io/ingress-nginx|true\n'; dash_detect >/dev/null 2>&1
DASH_WAY=ingress
# address, certificate: 2 = self-signed, y to confirm it, no IP limit
dash_run_steps >/dev/null 2>&1 <<'ANS'
kwatch.example.com
2
y

ANS
eq "piped flow ok" "$?" "0"
eq "piped address" "$DASH_ADDR" "kwatch.example.com"
eq "piped class picked" "$DASH_CLASS" "nginx"
eq "piped cert" "$DASH_CERT" "self"
eq "piped no ip limit" "$DASH_IPS" ""

if [ "$FAILS" -gt 0 ]; then
  printf 'dashboard-test: %s failure(s)\n' "$FAILS" >&2
  exit 1
fi
echo "dashboard-test: ok"
