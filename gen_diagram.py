#!/usr/bin/env python3
"""
Generate Jenkins Master/Slave CI/CD Architecture Diagram
mern-auth | PRCICD-001 & PRCICD-002
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import matplotlib.patheffects as pe

# ── Canvas ─────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(22, 14))
fig.patch.set_facecolor('#0D1117')
ax.set_facecolor('#0D1117')
ax.set_xlim(0, 22)
ax.set_ylim(0, 14)
ax.axis('off')

# ── Palette ────────────────────────────────────────────────────────────────────
C = {
    'master':   '#1E3A5F',
    'slave':    '#1A3A2A',
    'ext':      '#2D1B4E',
    'master_h': '#2563EB',
    'slave_h':  '#16A34A',
    'ext_h':    '#7C3AED',
    'arrow':    '#94A3B8',
    'warn':     '#EF4444',
    'gold':     '#F59E0B',
    'text':     '#F1F5F9',
    'dim':      '#64748B',
    'bg_lane':  '#161B22',
    'border':   '#30363D',
    'prci001':  '#1D4ED8',
    'prci002':  '#065F46',
}

def box(ax, x, y, w, h, color, alpha=0.85, radius=0.15):
    bp = FancyBboxPatch((x, y), w, h,
        boxstyle=f"round,pad=0,rounding_size={radius}",
        facecolor=color, edgecolor='#FFFFFF20',
        linewidth=0.6, alpha=alpha, zorder=3)
    ax.add_patch(bp)
    return bp

def label(ax, x, y, text, size=8, color='#F1F5F9', bold=False, zorder=4):
    weight = 'bold' if bold else 'normal'
    ax.text(x, y, text, fontsize=size, color=color, ha='center', va='center',
            fontweight=weight, zorder=zorder, wrap=True,
            path_effects=[pe.withStroke(linewidth=1.5, foreground='#0D111790')])

def arrow(ax, x1, y1, x2, y2, color='#94A3B8', style='->', lw=1.2):
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(arrowstyle=style, color=color,
                        lw=lw, connectionstyle='arc3,rad=0.0'),
        zorder=5)

def badge(ax, x, y, text, color):
    box(ax, x - 0.6, y - 0.18, 1.2, 0.36, color, alpha=0.9, radius=0.12)
    label(ax, x, y, text, size=6.5, color='#FFFFFF', bold=True)

# ── Lane Backgrounds ───────────────────────────────────────────────────────────
lanes = [
    (0.3,  0.5, 5.8,  13, C['master_h'], 'JENKINS MASTER\n(Orchestrator)'),
    (6.5,  0.5, 9.2,  13, C['slave_h'],  'JENKINS SLAVES\n(Workers — Ephemeral)'),
    (16.2, 0.5, 5.5,  13, C['ext_h'],    'EXTERNAL SYSTEMS'),
]
for (lx, ly, lw, lh, lc, lt) in lanes:
    bg = FancyBboxPatch((lx, ly), lw, lh,
        boxstyle="round,pad=0,rounding_size=0.25",
        facecolor=lc, edgecolor=lc,
        linewidth=1.5, alpha=0.12, zorder=1)
    ax.add_patch(bg)
    label(ax, lx + lw / 2, ly + lh - 0.5, lt, size=8.5, color=lc, bold=True)

# ── Title ──────────────────────────────────────────────────────────────────────
ax.text(11, 13.55,
    'End-to-End CI/CD Pipeline — mern-auth',
    fontsize=14, color='#F1F5F9', ha='center', va='center',
    fontweight='bold', zorder=6)
ax.text(11, 13.15,
    'Jenkins Master / Slave  ·  Kubernetes  ·  Prometheus  ·  PRCICD-001 & PRCICD-002',
    fontsize=8.5, color='#94A3B8', ha='center', va='center', zorder=6)

# ── Control legend ─────────────────────────────────────────────────────────────
badge(ax, 3.4, 12.65, 'PRCICD-001: Release Workflows', C['prci001'])
badge(ax, 3.4, 12.3,  'PRCICD-002: Build & Test Code',  C['prci002'])

# ── MASTER blocks ─────────────────────────────────────────────────────────────
master_items = [
    (0.5, 11.2, 5.4, 0.75, '#0F3460', '1  WEBHOOK TRIGGER\n(PR merge → main/release)', C['prci001']),
    (0.5, 9.35, 5.4, 0.75, '#0F3460', '9  MANUAL APPROVAL GATE\n(Release Manager sign-off)', C['prci001']),
    (0.5, 1.1,  5.4, 0.75, '#0F3460', '✓  RELEASE SUCCESSFUL\n(Audit trail stored)', C['prci001']),
    (0.5, 0.3,  5.4, 0.55, '#7F1D1D', '✗  PIPELINE FAILED\n(Auto-rollback + Slack alert)', '#EF4444'),
]
for (mx, my, mw, mh, mc, mt, badge_c) in master_items:
    box(ax, mx, my, mw, mh, mc, alpha=0.9)
    label(ax, mx + mw/2, my + mh/2, mt, size=7.5, bold=True)

# ── SLAVE blocks ───────────────────────────────────────────────────────────────
slave_data = [
    # (x, y, w, h, bg_color, title, tools, stage_num, badge_c)
    (6.6, 11.2, 9.0, 0.85, '#14532D', 'BUILD AGENT — Checkout & Compile',
     'Node.js · npm ci · React build', '1-2', C['prci002']),

    (6.6, 9.95, 9.0, 0.95, '#14532D', 'BUILD AGENT — Unit Tests & SAST',
     'Mocha / Jest · JUnit reporter · SonarQube scanner', '2-3', C['prci002']),

    (6.6, 8.65, 9.0, 0.95, '#14532D', 'BUILD AGENT — Docker Build + SCA (Trivy)',
     'Docker 24 · Trivy 0.51 · SBOM (CycloneDX)', '4', C['prci002']),

    (6.6, 7.45, 9.0, 0.85, '#14532D', 'BUILD AGENT — Push to Stage Registry',
     'docker push · tag :latest', '5', C['prci002']),

    (6.6, 6.2,  9.0, 0.95, '#1E3A5F', 'TEST AGENT — Integration Tests + DAST',
     'Newman (Postman) · OWASP ZAP · REST contract tests', '6-7', C['prci002']),

    (6.6, 5.0,  9.0, 0.85, '#1E3A5F', 'DEPLOY AGENT — Deploy to Staging (K8s)',
     'kubectl · Ingress · Smoke tests', '8', C['prci001']),

    (6.6, 3.75, 9.0, 0.85, '#14532D', 'BUILD AGENT — Push to Prod Registry',
     'docker retag · tag :stable', '10', C['prci001']),

    (6.6, 2.55, 9.0, 0.85, '#1E3A5F', 'DEPLOY AGENT — Production Blue/Green (K8s)',
     'kubectl set image · Service slot patch → Green', '11', C['prci001']),

    (6.6, 1.3,  9.0, 0.95, '#1E3A5F', 'TEST AGENT — Prometheus Monitor & Auto-Rollback',
     'Prometheus API query · error rate > 5% → rollback to Blue', '12', C['prci001']),
]
for (sx, sy, sw, sh, sc, st, stools, snum, badge_c) in slave_data:
    box(ax, sx, sy, sw, sh, sc, alpha=0.88)
    label(ax, sx + sw/2, sy + sh * 0.68, f'Stage {snum}  —  {st}', size=7.5, bold=True)
    label(ax, sx + sw/2, sy + sh * 0.25, stools, size=6.5, color='#94A3B8')

# ── EXTERNAL SYSTEM blocks ─────────────────────────────────────────────────────
ext_data = [
    (16.3, 11.2, 5.3, 0.85, '#1A1A3E', '⑆  GitHub\nmern-auth (dev branch)'),
    (16.3, 9.95, 5.3, 0.95, '#1A1A3E', '⊞  SonarQube\nQuality gate · Coverage ≥80%'),
    (16.3, 8.65, 5.3, 0.95, '#1A1A3E', '▤  Stage Registry\nregistry.internal/mern-auth-stage'),
    (16.3, 6.2,  5.3, 1.95, '#1A1A3E', '⬡  K8s Staging Cluster\nNamespace: mern-auth-staging\n2 replicas | Smoke tests'),
    (16.3, 3.75, 5.3, 0.85, '#1A1A3E', '▦  Prod Registry\nregistry.internal/mern-auth-prod'),
    (16.3, 1.3,  5.3, 2.1,  '#1A1A3E', '⬡  K8s Production Cluster\nBlue/Green deployment\nPrometheus scrape → alert'),
]
for (ex, ey, ew, eh, ec, et) in ext_data:
    box(ax, ex, ey, ew, eh, ec, alpha=0.88)
    label(ax, ex + ew/2, ey + eh/2, et, size=7.5, bold=True)

# ── ARROWS (Master → Slave) ────────────────────────────────────────────────────
# Webhook → Stage 1
arrow(ax, 3.2, 11.2, 9.5, 12.05, C['master_h'])
# Master approval gate → after Stage 8
arrow(ax, 3.2, 9.35, 9.5, 5.85,  C['master_h'])
# Stage 12 → Release Successful
arrow(ax, 9.5, 1.3, 3.2, 1.47, C['slave_h'])
# Stage 12 → Rollback path
arrow(ax, 11.1, 1.3, 11.1, 0.92, C['warn'], style='->')

# Slave → Slave (vertical flow inside slave lane)
slave_ys = [12.05, 10.43, 9.12, 7.87, 6.67, 5.43, 4.17, 2.97, 2.27]
for i in range(len(slave_ys) - 1):
    arrow(ax, 11.1, slave_ys[i+1] + 0.85, 11.1, slave_ys[i+1] + 1.05,
          C['slave_h'], style='->')

# Slave → External (stage registry, SonarQ, K8s, etc.)
ext_arrows = [
    (15.6, 9.95 + 0.45,  16.3, 9.95 + 0.45),   # SAST → SonarQube
    (15.6, 8.65 + 0.45,  16.3, 8.65 + 0.45),   # Docker → Stage Registry
    (15.6, 5.0  + 0.4,   16.3, 6.2  + 0.9),    # Deploy → K8s Staging
    (15.6, 3.75 + 0.4,   16.3, 3.75 + 0.4),    # Push → Prod Registry
    (15.6, 2.55 + 0.4,   16.3, 1.3  + 1.1),    # Deploy → K8s Prod
    (11.1, 11.2 + 0.4,   16.3, 11.2 + 0.4),    # Checkout → GitHub
]
for (ax1, ay1, bx1, by1) in ext_arrows:
    arrow(ax, ax1, ay1, bx1, by1, C['ext_h'])

# ── Quality gate diamonds ──────────────────────────────────────────────────────
def diamond(ax, cx, cy, label_text, color):
    d = 0.3
    xs = [cx, cx+d, cx, cx-d, cx]
    ys = [cy+d, cy, cy-d, cy, cy+d]
    ax.fill(xs, ys, color=color, alpha=0.9, zorder=5)
    ax.plot(xs, ys, color='white', linewidth=0.7, zorder=5)
    ax.text(cx, cy-0.52, label_text, fontsize=6, color=color,
            ha='center', va='center', fontweight='bold', zorder=6)

diamond(ax, 11.1, 10.9, 'Coverage ≥ 80%?', C['prci002'])
diamond(ax, 11.1, 8.3,  'ZAP Highs = 0?',  C['warn'])
diamond(ax, 11.1, 1.82, 'Error rate ≤ 5%?', '#10B981')

# ── Legend ─────────────────────────────────────────────────────────────────────
legend_x, legend_y = 0.4, 2.8
box(ax, legend_x - 0.1, legend_y - 0.1, 5.6, 1.95, '#161B22', alpha=0.95, radius=0.1)
label(ax, legend_x + 2.6, legend_y + 1.65, 'LEGEND', size=7.5, bold=True, color='#94A3B8')
legend_items = [
    (C['master_h'],  'Jenkins Master — orchestrator'),
    (C['slave_h'],   'Jenkins Slave — ephemeral worker'),
    (C['ext_h'],     'External system / K8s cluster'),
    (C['warn'],      'Auto-rollback / failure path'),
]
for i, (lc, lt) in enumerate(legend_items):
    ry = legend_y + 1.25 - i * 0.38
    box(ax, legend_x, ry - 0.12, 0.5, 0.25, lc, alpha=0.9, radius=0.05)
    ax.text(legend_x + 0.65, ry, lt, fontsize=6.5, color='#CBD5E1',
            va='center', fontweight='normal')

# ── Save ───────────────────────────────────────────────────────────────────────
out = r'c:\Users\Abhijit kadam\Desktop\Cloude\DevOps Competency-2\cicd_architecture_final.png'
plt.tight_layout(pad=0.1)
plt.savefig(out, dpi=180, bbox_inches='tight',
            facecolor=fig.get_facecolor())
plt.close()
print(f"Diagram saved → {out}")
