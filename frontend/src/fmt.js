const dateFmt = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })

export const fmtDate = (iso) => dateFmt.format(new Date(iso))
