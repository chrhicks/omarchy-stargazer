function location(name, latitudeText, longitudeText) {
  const decimal = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/
        if (!decimal.test(String(latitudeText).trim()) || !decimal.test(String(longitudeText).trim()))
  throw new Error("Enter decimal latitude and longitude, such as 51.48 and 0.00.")
  const latitude = Number(String(latitudeText).trim())
  const longitude = Number(String(longitudeText).trim())
  if (!String(latitudeText).trim() || !String(longitudeText).trim() || !isFinite(latitude) || Math.abs(
        latitude) > 90 || !isFinite(longitude) || Math.abs(longitude) > 180)
    throw new Error("Enter latitude from −90 to 90 and longitude from −180 to 180.")
  return {
    locationName: String(name).trim().slice(0, 160) || "Observing site",
    latitude: String(latitude),
    longitude: String(longitude)
  }
}

function writeLocation(config, values) {
  const layout = config.bar && config.bar.layout
  if (!layout)
    throw new Error("The bar configuration is unavailable. Reopen Stargazer and try again.")
  for (const section of ["left", "center", "right"]) {
    const entries = layout[section] || []
    const index = entries.findIndex(entry => entry === "chicks.stargazer" || entry && entry.id
                                             === "chicks.stargazer")
    if (index < 0)
      continue
    const entry = entries[index]
    entries[index] = Object.assign({}, typeof entry === "string" ? {
                                                                     id: entry
                                                                   } : entry, values)
    return
  }
  throw new Error("Stargazer is no longer in the bar. Enable it before saving a location.")
}
