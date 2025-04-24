const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = plugin(function ({ matchComponents, theme }) {
  let iconsDir = path.join(__dirname, "../../../../deps/fontawesome/svgs")
  let values = {}
  let icons = [
    ["regular", "/regular"],
    ["solid", "/solid"],
    ["brands", "/brands"]
  ]
  icons.forEach(([suffix, dir]) => {
    fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
      let name = suffix + "-" + path.basename(file, ".svg")
      values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
    })
  })
  matchComponents({
    "fa": ({ name, fullPath }) => {
      let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
      let size = theme("spacing.6")
      // if (name.endsWith("-mini")) {
      //   size = theme("spacing.5")
      // } else if (name.endsWith("-micro")) {
      //   size = theme("spacing.4")
      // }
      return {
        [`--fa-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
        "-webkit-mask": `var(--fa-${name})`,
        "mask": `var(--fa-${name})`,
        "mask-repeat": "no-repeat",
        "background-color": "currentColor",
        "vertical-align": "middle",
        "display": "inline-block",
        "width": size,
        "height": size
      }
    }
  }, { values })
})
