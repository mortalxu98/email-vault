#if os(macOS)
import SwiftUI
import EmailVaultCore

/// Due-date label for an account's renewal, colored by urgency.
struct RenewalBadge: View {
    let renewal: Renewal
    var compact: Bool = false

    var body: some View {
        let days = renewal.daysUntilDue()
        HStack(spacing: 4) {
            Image(systemName: "calendar.badge.clock")
            Text(days.map(L10n.renewalDue) ?? renewal.dueDate)
            if !compact {
                Text("· \(renewal.dueDate)")
                    .foregroundStyle(.secondary)
                if !renewal.amount.isEmpty {
                    Text("· \(renewal.amount)/\(L10n.renewalCycle(renewal.cycle))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(color(days))
        .lineLimit(1)
        .help("到期日 \(renewal.dueDate)，\(L10n.renewalCycle(renewal.cycle))，提前 \(renewal.leadDays) 天提醒")
    }

    private func color(_ days: Int?) -> Color {
        guard let days else { return .secondary }
        if days <= 0 { return .red }
        if days <= renewal.leadDays { return .orange }
        return .secondary
    }
}

/// Banner listing renewals inside their reminder window (or overdue).
struct RenewalBanner: View {
    @EnvironmentObject var model: AppModel
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "bell.badge.fill").foregroundStyle(.orange)
                    Text("续费提醒（\(model.dueRenewals.count)）").font(.headline)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(model.dueRenewals) { account in
                    if let renewal = account.renewal {
                        row(account, renewal)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
        .padding([.horizontal, .top])
    }

    private func row(_ account: AccountRecord, _ renewal: Renewal) -> some View {
        let logo = PlatformCatalog.platformLogo(platform: account.platform, url: account.url)
        return HStack(spacing: 10) {
            AvatarView(
                text: account.platform,
                logo: logo,
                size: 24,
                wide: PlatformCatalog.wideLogos.contains(logo ?? "")
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(account.platform).fontWeight(.medium)
                Text(account.emailAddress).font(.caption).foregroundStyle(.secondary)
            }
            .frame(minWidth: 140, alignment: .leading)
            RenewalBadge(renewal: renewal)
            Spacer()
            Button("查看") {
                model.searchQuery = ""
                model.selectEmail(account.emailId)
            }
            Button(renewal.cycle == .once ? "已处理" : "已续费") {
                model.markRenewed(account)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .help(renewal.cycle == .once ? "移除这条提醒" : "到期日顺延一个周期")
        }
    }
}

/// Renewal rows inside the account editor's Form.
struct RenewalEditorSection: View {
    @Binding var enabled: Bool
    @Binding var dueDate: Date
    @Binding var cycle: RenewalCycle
    @Binding var amount: String
    @Binding var leadDays: Int

    var body: some View {
        Toggle("续费提醒", isOn: $enabled)
        if enabled {
            DatePicker("到期日", selection: $dueDate, displayedComponents: .date)
            Picker("周期", selection: $cycle) {
                ForEach(RenewalCycle.allCases, id: \.self) { c in
                    Text(L10n.renewalCycle(c)).tag(c)
                }
            }
            .pickerStyle(.segmented)
            TextField("金额", text: $amount, prompt: Text("可选，如 ¥99"))
            Stepper("提前 \(leadDays) 天提醒", value: $leadDays, in: 0...90)
        }
    }
}
#endif
