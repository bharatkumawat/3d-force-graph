//@version=6
strategy("Protected Multi-Stock Strategy v6 - Pro", overlay=true, initial_capital=100000, default_qty_type=strategy.percent_of_equity, default_qty_value=20, calc_on_every_tick=true)

// --- DASHBOARD POSITION INPUTS ---
h_pos = input.string("right", "Horizontal Position", options=["left", "center", "right"], group="Dashboard Position")
v_pos = input.string("top", "Vertical Position", options=["top", "middle", "bottom"], group="Dashboard Position")

// --- TAX & CHARGES INPUTS ---
flat_brokerage = input.float(20.0, "Flat Brokerage per Order (Buy/Sell)", group="Charges")
brokerage_per  = input.float(0.0, "Extra Brokerage % (if any)", step=0.01, group="Charges") / 100
stt_per        = input.float(0.1, "STT % (Delivery)", step=0.01, group="Charges") / 100
stamp_per      = input.float(0.015, "Stamp Duty % (Buy Side)", step=0.015, group="Charges") / 100
sebi_per       = input.float(0.0001, "SEBI Charges %", step=0.0001, group="Charges") / 100
gst_per        = input.float(12.5, "GST % (on Brokerage+SEBI)", step=0.1, group="Charges") / 100

// --- INDICATORS ---
vwap_val = ta.vwap(hlc3)
sma_long = ta.sma(close, 200)
atr_val  = ta.atr(14)

// --- PLOTTING ---
plot(vwap_val, color=color.new(color.blue, 0), title="VWAP")
plot(sma_long, color=color.new(color.white, 0), title="SMA 200", linewidth=2)

// --- ENTRY LOGIC ---
longCondition = close > vwap_val and close > sma_long
if longCondition and strategy.position_size == 0
    strategy.entry("Long", strategy.long, comment="ENTRY")

// --- EXIT LOGIC ---
if strategy.position_size > 0
    target_price = strategy.position_avg_price * 1.06
    trail_offset_ticks = (atr_val * 2.5) / syminfo.mintick
    strategy.exit("Exit", "Long", limit=target_price, trail_points=0, trail_offset=trail_offset_ticks, comment_loss="STOP", comment_profit="TARGET")

if close < vwap_val * 0.997
    strategy.close("Long", comment="VWAP EXIT")

// --- REAL-TIME ACCURATE CALCULATIONS ---
total_trades     = strategy.closedtrades
total_orders     = total_trades * 2 // 1 Buy + 1 Sell per closed trade
total_turnover   = strategy.grossprofit + math.abs(strategy.grossloss)
buy_turnover     = total_turnover / 2

// Charge Breakdown
total_flat_brokerage = total_orders * flat_brokerage
total_perc_brokerage = total_turnover * brokerage_per
total_stt            = total_turnover * stt_per
total_sebi           = total_turnover * sebi_per
total_stamp          = buy_turnover * stamp_per
gst_on_charges       = (total_flat_brokerage + total_perc_brokerage + total_sebi) * gst_per

// Net Totals
total_deductions = total_flat_brokerage + total_perc_brokerage + total_stt + total_sebi + total_stamp + gst_on_charges
final_net_profit = strategy.netprofit - total_deductions

// Drawdown Calculation
current_drawdown = strategy.max_drawdown / (strategy.initial_capital + strategy.netprofit) * 100

// --- DASHBOARD TABLE ---
pos_final = h_pos == "left" ? (v_pos == "top" ? position.top_left : v_pos == "middle" ? position.middle_left : position.bottom_left) : h_pos == "center" ? (v_pos == "top" ? position.top_center : v_pos == "middle" ? position.middle_center : position.bottom_center) : (v_pos == "top" ? position.top_right : v_pos == "middle" ? position.middle_right : position.bottom_right)

var table tax_tab = table.new(pos_final, 2, 7, color.new(color.black, 0), color.white, 1)

if barstate.islast or barstate.isrealtime
    table.cell(tax_tab, 0, 0, "Total Trades", bgcolor=color.new(color.gray, 0), text_color=color.white)
    table.cell(tax_tab, 1, 0, str.tostring(total_trades), text_color=color.white)
    table.cell(tax_tab, 0, 1, "Max Drawdown %", bgcolor=color.new(color.purple, 0), text_color=color.white)
    table.cell(tax_tab, 1, 1, str.tostring(current_drawdown, "#.##") + "%", text_color=color.white)
    table.cell(tax_tab, 0, 2, "STT + Stamp", bgcolor=color.new(color.orange, 0), text_color=color.white)
    table.cell(tax_tab, 1, 2, str.tostring(total_stt + total_stamp, "#.##"), text_color=color.white)
    table.cell(tax_tab, 0, 3, "Brokerage (Flat+%)", bgcolor=color.new(color.blue, 0), text_color=color.white)
    table.cell(tax_tab, 1, 3, str.tostring(total_flat_brokerage + total_perc_brokerage, "#.##"), text_color=color.white)
    table.cell(tax_tab, 0, 4, "GST + SEBI", bgcolor=color.new(color.red, 0), text_color=color.white)
    table.cell(tax_tab, 1, 4, str.tostring(gst_on_charges + total_sebi, "#.##"), text_color=color.white)
    table.cell(tax_tab, 0, 5, "Total Charges", bgcolor=color.new(color.gray, 0), text_color=color.white)
    table.cell(tax_tab, 1, 5, str.tostring(total_deductions, "#.##"), text_color=color.white)
    table.cell(tax_tab, 0, 6, "NET PROFIT (Final)", bgcolor=color.new(color.green, 0), text_color=color.white)
    table.cell(tax_tab, 1, 6, str.tostring(final_net_profit, "#.##"), text_color=color.white, text_size=size.large)