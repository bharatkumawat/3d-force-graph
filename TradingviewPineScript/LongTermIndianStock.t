//@version=6
strategy(
     "Protected Multi-Stock Strategy v6.2 | Final",
     overlay=true,
     initial_capital=100000,
     default_qty_type=strategy.percent_of_equity,
     default_qty_value=100,
     pyramiding=2,
     calc_on_every_tick=true
)

// ==========================================================
// ADX CALCULATION (Pine v6 Compatible)
// ==========================================================
f_adx(_len) =>
    [plusDI, minusDI, adxValue] = ta.dmi(_len, _len)
    adxValue

// ==========================================================
// DATE & DASHBOARD POSITION SETTINGS
// ==========================================================
use_custom      = input.bool(false, "Use Custom Date Range", group="Date Settings")
lookback_type   = input.string("All Time", "Test Period", options=["Last 7 Days", "Last 1 Month", "Last 3 Months", "All Time"], group="Date Settings")
show_dashboard  = input.bool(true, "Show Dashboard", group="Dashboard")
h_pos           = input.string("right", "Horizontal Position", options=["left", "center", "right"], group="Dashboard")
v_pos           = input.string("top", "Vertical Position", options=["top", "middle", "bottom"], group="Dashboard")

custom_start = input.time(timestamp("2026-01-01 09:15"), "Custom Start", group="Date Settings")
custom_end   = input.time(timestamp("2026-02-07 15:30"), "Custom End", group="Date Settings")

int lookback_ms = lookback_type == "Last 7 Days"   ? 7  * 24 * 60 * 60 * 1000 :
                  lookback_type == "Last 1 Month" ? 30 * 24 * 60 * 60 * 1000 :
                  lookback_type == "Last 3 Months"? 90 * 24 * 60 * 60 * 1000 : 0

auto_start = timenow - lookback_ms
is_in_date = use_custom ? (time >= custom_start and time <= custom_end) :
             lookback_type == "All Time" ? true : (time >= auto_start)

// Dashboard Positioning Logic
pos_final = h_pos == "left" ? (v_pos == "top" ? position.top_left : v_pos == "middle" ? position.middle_left : position.bottom_left) : 
     h_pos == "center" ? (v_pos == "top" ? position.top_center : v_pos == "middle" ? position.middle_center : position.bottom_center) : 
     (v_pos == "top" ? position.top_right : v_pos == "middle" ? position.middle_right : position.bottom_right)

// ==========================================================
// INDICATORS
// ==========================================================
vwap_val   = ta.vwap(hlc3)
sma_200    = ta.sma(close, 200)
atr_val    = ta.atr(14)
adx_val    = f_adx(14)
vol_sma    = ta.sma(volume, 20)
rvol       = volume / vol_sma
vwap_slope = ta.linreg(vwap_val, 5, 0)

// ==========================================================
// ENTRY & EXIT LOGIC
// ==========================================================
breakout = close > high[1] and close > open
primary_long = is_in_date and close > vwap_val and close > sma_200 and vwap_slope > vwap_slope[1] and rvol > 1.2 and adx_val > 20 and breakout

if primary_long and strategy.position_size == 0
    strategy.entry("Long", strategy.long, comment="BASE BUY")

add_long = strategy.position_size > 0 and close > vwap_val and close > high[1] and rvol > 1.3
if add_long
    strategy.entry("Add", strategy.long, qty=30, comment="PYRAMID ADD")

if strategy.position_size > 0
    if rvol > 2.5 and close < open
        strategy.close_all(comment="VOL CLIMAX")
    target_price = strategy.position_avg_price * 1.08
    trail_offset = (atr_val * 2.5) / syminfo.mintick
    strategy.exit("Exit", "Long", limit=target_price, trail_offset=trail_offset)
    strategy.exit("Exit Add", "Add", limit=target_price, trail_offset=trail_offset)

if close < vwap_val * 0.997
    strategy.close_all(comment="VWAP BREAK")

// ==========================================================
// 2026 EQUITY DELIVERY CHARGES & DRAWDOWN
// ==========================================================
flat_brokerage_val = input.float(20.0, "Flat Brokerage (per side)", group="Charges")
total_trades       = strategy.closedtrades
turnover           = strategy.grossprofit + math.abs(strategy.grossloss)
buy_turnover       = turnover / 2

total_flat_brokerage = total_trades * 2 * flat_brokerage_val
total_stt            = turnover * 0.001
total_stamp          = buy_turnover * 0.00015
total_sebi           = turnover * 0.000001
total_exch           = turnover * 0.0000345
gst_on_charges       = (total_flat_brokerage + total_sebi + total_exch) * 0.18

total_deductions     = total_flat_brokerage + total_stt + total_stamp + total_sebi + total_exch + gst_on_charges
final_net_profit     = strategy.netprofit - total_deductions

// Correct Drawdown Calculation for v6
max_equity = ta.highest(strategy.equity, 500)
current_drawdown = strategy.equity < max_equity ? ((max_equity - strategy.equity) / max_equity) * 100 : 0

// ==========================================================
// DASHBOARD DISPLAY LOGIC
// ==========================================================
var table tax_tab = table.new(pos_final, 2, 8, color.new(color.black, 0), color.white, 1)

if show_dashboard and (barstate.islast or barstate.isrealtime)
    display_period = use_custom ? "Custom" : lookback_type
    table.cell(tax_tab, 0, 0, "Period", bgcolor=color.new(color.gray, 0), text_color=color.white)
    table.cell(tax_tab, 1, 0, display_period, text_color=color.white)
    table.cell(tax_tab, 0, 1, "Total Trades", bgcolor=color.new(color.gray, 0), text_color=color.white)
    table.cell(tax_tab, 1, 1, str.tostring(total_trades), text_color=color.white)
    table.cell(tax_tab, 0, 2, "Max Drawdown %", bgcolor=color.new(color.purple, 0), text_color=color.white)
    table.cell(tax_tab, 1, 2, str.tostring(current_drawdown, "#.##") + "%", text_color=color.white)
    table.cell(tax_tab, 0, 3, "STT + Stamp", bgcolor=color.new(color.orange, 0), text_color=color.white)
    table.cell(tax_tab, 1, 3, str.tostring(total_stt + total_stamp, "#.##"), text_color=color.white)
    table.cell(tax_tab, 0, 4, "Brokerage (Flat)", bgcolor=color.new(color.blue, 0), text_color=color.white)
    table.cell(tax_tab, 1, 4, str.tostring(total_flat_brokerage, "#.##"), text_color=color.white)
    table.cell(tax_tab, 0, 5, "GST + SEBI", bgcolor=color.new(color.red, 0), text_color=color.white)
    table.cell(tax_tab, 1, 5, str.tostring(gst_on_charges + total_sebi, "#.##"), text_color=color.white)
    table.cell(tax_tab, 0, 6, "Total Charges", bgcolor=color.new(color.gray, 0), text_color=color.white)
    table.cell(tax_tab, 1, 6, str.tostring(total_deductions, "#.##"), text_color=color.white)
    table.cell(tax_tab, 0, 7, "NET PROFIT (Final)", bgcolor=color.new(color.green, 0), text_color=color.white)
    table.cell(tax_tab, 1, 7, str.tostring(final_net_profit, "#.##"), text_color=color.white, text_size=size.large)
else if not show_dashboard
    table.clear(tax_tab, 0, 0, 1, 7)

// Visuals
plot(vwap_val, color=color.blue, title="VWAP")
plot(sma_200,  color=color.white, linewidth=2, title="SMA 200")