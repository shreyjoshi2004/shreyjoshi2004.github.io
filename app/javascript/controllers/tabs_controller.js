import { Controller } from "@hotwired/stimulus"

// Accessible tabs: <nav> holds [role=tab] buttons, panels are [role=tabpanel].
// The active tab is mirrored in location.hash so tabs are linkable.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.select(this.#indexFromHash() ?? 0, { updateHash: false })
  }

  show(event) {
    this.select(this.tabTargets.indexOf(event.currentTarget))
  }

  hashChanged() {
    const index = this.#indexFromHash()
    if (index !== null) this.select(index, { updateHash: false })
  }

  keydown(event) {
    const last = this.tabTargets.length - 1
    const current = this.tabTargets.indexOf(document.activeElement)
    if (current < 0) return

    const target = {
      ArrowRight: current === last ? 0 : current + 1,
      ArrowLeft: current === 0 ? last : current - 1,
      Home: 0,
      End: last
    }[event.key]
    if (target === undefined) return

    event.preventDefault()
    this.select(target)
    this.tabTargets[target].focus()
  }

  select(index, { updateHash = true } = {}) {
    this.tabTargets.forEach((tab, i) => {
      const active = i === index
      tab.setAttribute("aria-selected", active)
      tab.tabIndex = active ? 0 : -1
    })
    this.panelTargets.forEach((panel, i) => { panel.hidden = i !== index })

    if (updateHash) history.replaceState(null, "", `#${this.panelTargets[index].id}`)
  }

  #indexFromHash() {
    const id = location.hash.slice(1)
    const index = this.panelTargets.findIndex((panel) => panel.id === id)
    return index < 0 ? null : index
  }
}
