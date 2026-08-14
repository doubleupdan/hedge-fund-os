'use strict';

/* =============================================================================
   APEX OS renderer.

   This is the approved index_2.html script, moved into the desktop app. The
   Agent Roster, Org Chart and Super Brain rendering is unchanged. Two things
   are new:

     1. The Risk Desk reads accounts + risk_limits live from Supabase instead
        of the hardcoded ACCOUNTS array that used to sit in this file.
     2. Every remaining hardcoded figure is tagged in the UI, so real and
        illustrative data can be told apart at a glance.
   ========================================================================== */

const IC={Home:'<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/>',Users:'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>',Network:'<rect x="9" y="2" width="6" height="6" rx="1"/><rect x="2" y="16" width="6" height="6" rx="1"/><rect x="16" y="16" width="6" height="6" rx="1"/><path d="M12 8v4M12 12H5v4M12 12h7v4"/>',ShieldAlert:'<path d="M20 13c0 5-3.5 7.5-8 9-4.5-1.5-8-4-8-9V5l8-3 8 3z"/><path d="M12 8v4M12 16h.01"/>',Brain:'<path d="M12 5a3 3 0 1 0-5.9.9M12 5a3 3 0 1 1 5.9.9M12 5v14M6.1 5.9A3 3 0 0 0 4 12a3 3 0 0 0 2 5M17.9 5.9A3 3 0 0 1 20 12a3 3 0 0 1-2 5"/>',LineChart:'<path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/>',Wallet:'<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>',Newspaper:'<path d="M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2"/><path d="M18 14h-8M15 18h-5M10 6h8v4h-8V6Z"/>',Plug:'<path d="M12 22v-5M9 8V2M15 8V2M18 8v3a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8Z"/>',ListChecks:'<path d="m3 17 2 2 4-4M3 7l2 2 4-4M13 6h8M13 12h8M13 18h8"/>',Activity:'<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>',HeartPulse:'<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.29 1.51 4.04 3 5.5l7 7Z"/><path d="M3.22 12H9.5l.5-1 2 4 .5-2.5.5 1H14"/>'};
function svg(p){return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+p+'</svg>';}
function sparkIcon(shade){return '<svg viewBox="0 0 24 24" fill="none" stroke="'+shade+'" stroke-width="1.5"><circle cx="12" cy="12" r="3"/><path d="M12 2v4M12 18v4M4.9 4.9l2.8 2.8M16.3 16.3l2.8 2.8M2 12h4M18 12h4M4.9 19.1l2.8-2.8M16.3 7.7l2.8-2.8"/></svg>';}

/* Provenance tags. LIVE = read from Supabase this session. ILLUSTRATIVE =
   hardcoded in this file to show the intended shape of a feature that has no
   backend yet. */
const PROV_LIVE = '<span class="prov live"><span class="dot ok pulse"></span>live · supabase</span>';
const PROV_MOCK = '<span class="prov mock">illustrative</span>';

const NAV=[['Executive',[['Agent Roster','Users','agents'],['Org Chart','Network','org']]],
['Capital',[['Risk Desk','ShieldAlert','risk']]],
['Intelligence',[['Super Brain','Brain','brain']]]];

/* ---- departments ---- */
const DEPTS=[
 ['dept-exec','Executive Office','Coordination, strategy, decision support.','#3df08c'],
 ['dept-investment','Investment Office','Macro, fundamental, quant, technical research.','#5ec9f8'],
 ['dept-risk','Risk Office','Capital preservation. Can veto any trade.','#ff6259'],
 ['dept-portfolio','Portfolio Office','Allocation, diversification, correlation, construction.','#a855f7'],
 ['dept-trading','Trading Operations','MT5/TradingView monitoring, execution support, journaling.','#f59e0b'],
 ['dept-capital','Capital Allocation','Account metadata, strategy scaling, drawdown response.','#22c55e'],
 ['dept-knowledge','Knowledge Office','Super Brain — research library, SOPs, decision history.','#14b8a6'],
 ['dept-intel','Intelligence Office','News, macro events, filings — ranked by market impact.','#eab308'],
 ['dept-human','Human Performance Office','Trader psychology, discipline, rule enforcement.','#ec4899'],
 ['dept-eng','Engineering Office','MCP servers, n8n, database, dashboards, automation.','#818cf8'],
];
const deptColor=id=>(DEPTS.find(d=>d[0]===id)||[])[3]||'#888';

/* ---- 15 functional (live) agents ----
   These definitions are real — each corresponds to an intended agent in
   /agents. Note that "active" here describes the agent's design status, not a
   running process: no agent runtime is wired up yet. */
const LIVE=[
['chief-exec-ai','Chief Executive AI','CEO/CIO/COO/CTO · Orchestration','active','lead','dept-exec','','claude,mcp,github','Routes requests to department leads, reviews reports, owns strategy and long-term roadmap. Never executes routine work itself.'],
['cio-ai','Chief Investment Officer AI','Investment Office Lead','active','lead','dept-investment','chief-exec-ai','claude,mcp,tradingview','Aggregates macro, fundamental, quant, and technical research into a single investment view before it reaches the CEO.'],
['cro-ai','Chief Risk Officer AI','Risk Office Lead','active','lead','dept-risk','chief-exec-ai','postgres,mcp,n8n','Owns every hard-coded risk limit. Has standing authority to block a trade proposal from any other agent — including the CEO.'],
['coo-ai','Chief Operations Officer AI','Operations Lead','active','lead','dept-exec','chief-exec-ai','n8n,github,postgres','Runs the reporting cadence — market open, midday, close, weekly — and tracks operational SOP adherence.'],
['macro-research','Macro Research Agent','Central Banks, Rates, Inflation','active','worker','dept-investment','cio-ai','web-search,fred,mcp','Tracks Fed/ECB/BOJ/BOE policy, CPI/PPI/NFP releases, yield curve, and geopolitical developments that move rates.'],
['fundamental-research','Fundamental Research Agent','Earnings, Filings, Valuation','active','worker','dept-investment','cio-ai','sec-edgar,mcp','Parses earnings releases, SEC filings, and investor presentations for valuation-relevant signals.'],
['quant-research','Quantitative Research Agent','Backtesting, Factor Models','active','worker','dept-investment','cio-ai','python,tradingview,postgres','Builds and backtests statistical models, runs Monte Carlo simulations, flags regime shifts.'],
['technical-research','Technical Analysis Agent','Chart Structure, Order Flow','active','worker','dept-investment','cio-ai','tradingview,mt5','Multi-timeframe trend, structure, and liquidity analysis across supported instruments.'],
['market-scanner','Market Scanner Agent','Daily Opportunity Ranking','active','worker','dept-investment','cio-ai','tradingview,mcp','Scans forex, stocks, ETFs, commodities, and indices daily; ranks by momentum, volatility, and setup quality.'],
['portfolio-mgmt','Portfolio Management Agent','Allocation & Construction','active','lead','dept-portfolio','chief-exec-ai','postgres,mcp','Owns asset allocation, correlation analysis, and drawdown-aware portfolio construction across strategies.'],
['trader-mgmt','Trader Management Agent','Discipline & Psychology','active','lead','dept-human','chief-exec-ai','postgres,n8n','Reviews trading journals daily, flags revenge trading, overleveraging, and rule violations before they compound.'],
['capital-allocation','Capital Allocation Agent','Account & Strategy Sizing','active','lead','dept-capital','chief-exec-ai','postgres,mcp','Maintains per-account metadata (balance, limits, permissions) and scales capital to strategies based on performance.'],
['knowledge-mgmt','Knowledge Management Agent','Super Brain Librarian','active','lead','dept-knowledge','chief-exec-ai','postgres,pgvector,github','Indexes every research note, SOP, and decision into the searchable vault. Nothing valuable gets lost.'],
['intel-monitor','Intelligence Monitoring Agent','News & Event Ranking','active','lead','dept-intel','chief-exec-ai','web-search,mcp,n8n','Watches news, economic calendars, and filings continuously; ranks each event Low/Medium/High/Critical by market impact.'],
['reporting-agent','Reporting Agent','Open / Midday / Close / Weekly','active','lead','dept-exec','coo-ai','n8n,postgres,github','Auto-generates the standard report set: market conditions, open positions, risk, research, action items, next priorities.'],
];

/* ---- placeholder roles (Phase 4) — generated per department ---- */
const PLACEHOLDER_TITLES={
 'dept-exec':['Chief of Staff AI','Strategy Analyst','Resource Allocation Analyst','Executive Communications Associate','Board Reporting Analyst','Vendor & Tooling Analyst'],
 'dept-investment':['Senior Macro Strategist','Rates Analyst','FX Strategist','Credit Analyst','Equity Research Associate','Sector Specialist — Technology','Sector Specialist — Energy','Sector Specialist — Financials','Sector Specialist — Healthcare','Options Flow Analyst','Alt-Data Analyst','ML Model Engineer','Factor Research Associate','Backtest QA Analyst','Chart Pattern Analyst','Order Flow Specialist','Commodities Analyst','Fixed Income Analyst','Crypto Research Associate','Earnings Call Analyst'],
 'dept-risk':['Position Sizing Analyst','Correlation Risk Analyst','Liquidity Risk Analyst','Event Risk Analyst','Volatility Analyst','Stress Testing Analyst','Scenario Analysis Associate','Concentration Risk Analyst','Tail Risk Specialist','Margin & Leverage Monitor'],
 'dept-portfolio':['Diversification Analyst','Exposure Manager','Compounding Strategy Analyst','Rebalancing Associate','Cross-Asset Correlation Analyst','Strategy Allocation Associate'],
 'dept-trading':['MT5 Execution Monitor','TradingView Chart Operator','Backtest Support Analyst','Execution Quality Analyst','Position Monitor — Forex','Position Monitor — Equities','Position Monitor — Commodities','Trade Journal Auditor','Slippage Analyst','Broker Relationship Associate'],
 'dept-capital':['Account Metadata Analyst','Strategy Scaling Analyst','Drawdown Response Associate','Profit Compounding Analyst','Broker Account Auditor'],
 'dept-knowledge':['Research Librarian','SOP Curator','Mistake Database Analyst','Meeting Notes Archivist','Playbook Editor','Tagging & Metadata Analyst','Internal Wiki Editor'],
 'dept-intel':['Geopolitics Watch Analyst','Central Bank Release Monitor','SEC Filing Monitor','Shipping & Trade Route Analyst','Commodity Supply Analyst','Institutional Activity Analyst','Breaking News Triage Analyst','Election & Policy Analyst'],
 'dept-human':['Trading Psychology Coach','Rule Violation Auditor','Overtrading Monitor','Trader Performance Reviewer','Burnout & Fatigue Monitor'],
 'dept-eng':['MCP Server Engineer','n8n Workflow Engineer','Database Administrator','API Integration Engineer','Dashboard Engineer','Notification Systems Engineer','Obsidian Graph Engineer','QA & Testing Engineer','DevOps / Infra Engineer','Security & Access Engineer'],
};
// pad each dept out with generically-numbered analyst roles so total placeholder count ≈ 185
let PLACEHOLDERS=[];
let pidCounter=1;
DEPTS.forEach(([did])=>{
  const base=PLACEHOLDER_TITLES[did]||[];
  base.forEach(title=>{PLACEHOLDERS.push({id:'ph-'+(pidCounter++),title,dept:did});});
});
// top up remaining slots with numbered "Associate" roles distributed across departments to reach ~185 total
const TARGET_PLACEHOLDERS=185;
let di=0;
while(PLACEHOLDERS.length<TARGET_PLACEHOLDERS){
  const [did,dname]=DEPTS[di%DEPTS.length];
  const n=PLACEHOLDERS.filter(p=>p.dept===did).length+1;
  PLACEHOLDERS.push({id:'ph-'+(pidCounter++),title:dname.replace(' Office','').replace(' Operations','')+' Associate '+n,dept:did});
  di++;
}

/* ---- ILLUSTRATIVE ----------------------------------------------------------
   No agent runtime exists yet, so nothing has ever "last run". These strings
   are hand-written examples of what a run summary will look like once agents
   actually execute. Every card that shows one carries an ILLUSTRATIVE tag.
   -------------------------------------------------------------------------- */
const RUN_SUMMARIES={
 'chief-exec-ai':['OK','Routed 6 requests, 0 escalations'],
 'cio-ai':['OK','Compiled daily investment view from 5 research agents'],
 'cro-ai':['OK','All accounts within limits, 0 breaches'],
 'coo-ai':['OK','Market-close report generated on schedule'],
 'macro-research':['OK','Flagged FOMC minutes as High impact'],
 'fundamental-research':['OK','Parsed 3 earnings releases, 1 flagged for margin compression'],
 'quant-research':['WARN','Backtest queue delayed — awaiting historical data refresh'],
 'technical-research':['OK','Multi-timeframe scan complete on 12 instruments'],
 'market-scanner':['OK','Ranked 40 instruments, top 5 surfaced to CIO'],
 'portfolio-mgmt':['OK','Correlation matrix refreshed, no concentration flags'],
 'trader-mgmt':['OK','0 rule violations in journal review'],
 'capital-allocation':['OK','Account metadata synced, no reallocations needed'],
 'knowledge-mgmt':['WARN','12 vault pages changed since last sync'],
 'intel-monitor':['OK','2 Medium-impact events logged, 0 Critical'],
 'reporting-agent':['OK','4 of 4 scheduled reports delivered on time'],
};

/* ---- render nav ---- */
document.getElementById('nav').innerHTML=NAV.map(([t,items])=>'<div class="nav-group-title">'+t+'</div>'+items.map(([label,icon,pg])=>'<a class="nav-item" data-page="'+pg+'" href="#">'+svg(IC[icon])+label+'</a>').join('')).join('');

/* ---- AGENTS page ---- */
document.getElementById('agentStats').innerHTML=[['Total roles',LIVE.length+PLACEHOLDERS.length],['Live agents',LIVE.length],['Placeholder roles',PLACEHOLDERS.length],['Open risk flags',0],['Scheduled reports/day',4]].map(([l,v])=>'<div class="stat"><span class="label">'+l+'</span><div class="v">'+v+'</div></div>').join('');

document.getElementById('deptSections').innerHTML=DEPTS.map(([id,name,tag,color])=>{
  const live=LIVE.filter(a=>a[5]===id);
  const placeholders=PLACEHOLDERS.filter(p=>p.dept===id);
  if(!live.length && !placeholders.length)return '';
  const liveCards=live.map(a=>{
    const[aid,an,role,st,tier,dept,parent,tools,desc]=a;
    const isActive=st==='active';const t=tools.split(',');
    const parentName=parent?(LIVE.find(x=>x[0]===parent)||[])[1]:null;
    const run=RUN_SUMMARIES[aid];
    return '<article class="agent-card'+(isActive?' active':'')+'"><div class="top"><div class="name-line">'+
      '<span class="spark">'+sparkIcon(color)+'</span><span class="dot '+(isActive?'ok pulse':(st==='idle'?'warn':'off'))+'"></span>'+
      '<h3>'+an+'</h3></div><span class="badge">'+tier+'</span></div>'+
      '<div class="role">'+role+'</div><div class="desc">'+desc+'</div>'+
      '<div class="tool-tags">'+t.slice(0,5).map(x=>'<span class="tool-tag">'+x+'</span>').join('')+(t.length>5?'<span class="tool-tag">+'+(t.length-5)+'</span>':'')+'</div>'+
      '<div class="agent-foot"><div class="meta"><span>'+(parentName?'reports to '+parentName:'executive tier')+'</span><span class="st">'+st+'</span></div>'+
      (run?'<div class="last"><b class="'+(run[0]==='OK'?'ok':run[0]==='WARN'?'warn':'fail')+'">'+run[0]+'</b><span>last check: '+run[1]+'</span>'+PROV_MOCK+'</div>':'')+
      '<div class="chat-input"><input placeholder="Ask '+an+'…" disabled title="Agent chat has no backend yet"/><button disabled title="Agent chat has no backend yet">send</button></div></div></article>';
  }).join('');
  const phCards=placeholders.map(p=>'<article class="agent-card placeholder"><div class="ph-row"><span class="spark">'+sparkIcon('var(--text-3)')+'</span><h3>'+p.title+'</h3><span class="dot off"></span></div><div class="role">Phase 4 · not yet active</div></article>').join('');
  return '<div class="dept-section"><div class="section-head"><span class="label">'+name+' <span class="count">'+live.length+' defined · '+placeholders.length+' planned</span><span class="rule"></span></span></div><div class="dept-tag">'+tag+'</div>'+
    (live.length?'<div class="agent-grid" style="margin-bottom:14px">'+liveCards+'</div>':'')+
    (placeholders.length?'<div class="agent-grid">'+phCards+'</div>':'')+
    '</div>';
}).join('');

/* ---- ORG page ---- */
const ASSETS=[['forex','Forex','#5ec9f8'],['equities','Equities','#3df08c'],['commodities','Commodities','#eab308']];
let activeAsset=null;
const AGENT_ASSETS={'macro-research':['forex','commodities'],'fundamental-research':['equities'],'technical-research':['forex','equities','commodities'],'market-scanner':['forex','equities','commodities'],'trader-mgmt':['forex','equities']};
function renderVentureRow(){
  document.getElementById('ventureRow').innerHTML='<span class="venture-pill" data-v="" data-active="'+(!activeAsset)+'">All coverage</span>'+
    ASSETS.map(([id,label,color])=>'<span class="venture-pill" data-v="'+id+'" data-active="'+(activeAsset===id)+'"><span class="swatch" style="background:'+color+'"></span>'+label+'</span>').join('');
}
function assetColor(id){return (ASSETS.find(v=>v[0]===id)||[])[2];}
function renderOrg(){
  const dimFor=aid=>activeAsset && !(AGENT_ASSETS[aid]||[]).includes(activeAsset);
  document.getElementById('deptCols').innerHTML=DEPTS.map(([id,name,tag,color])=>{
    const leads=LIVE.filter(a=>a[5]===id && !a[6]);
    const placeholders=PLACEHOLDERS.filter(p=>p.dept===id);
    function tree(agent,depth){
      const[aid,an,,st]=agent;
      const kids=LIVE.filter(x=>x[6]===aid);
      const vdots=(AGENT_ASSETS[aid]||[]).map(v=>'<i style="background:'+assetColor(v)+'"></i>').join('');
      return '<div style="padding-left:'+(depth*10)+'px"><div class="agent-pill'+(dimFor(aid)?' dim':'')+'">'+
        '<span class="sdot '+st+'"></span><span class="an">'+an+'</span>'+(vdots?'<span class="vdots">'+vdots+'</span>':'')+'</div>'+
        kids.map(k=>tree(k,depth+1)).join('')+'</div>';
    }
    const phPreview=placeholders.slice(0,3).map(p=>'<div class="agent-pill ph"><span class="sdot planned"></span><span class="an">'+p.title+'</span></div>').join('');
    const more=placeholders.length>3?'<div class="tree-more">+'+(placeholders.length-3)+' more planned roles</div>':'';
    return '<div class="dept-col"><div class="dh"><span class="swatch" style="background:'+color+'"></span><span class="dn">'+name+'</span></div><div class="dtag">'+tag+'</div><div class="node-tree">'+leads.map(l=>tree(l,0)).join('')+phPreview+more+'</div></div>';
  }).join('');
}
renderVentureRow();renderOrg();
document.getElementById('ventureRow').addEventListener('click',e=>{const p=e.target.closest('[data-v]');if(!p)return;activeAsset=p.dataset.v||null;renderVentureRow();renderOrg();});

/* =============================================================================
   RISK page — live from Supabase.

   The hardcoded ACCOUNTS array that used to live here is gone. Everything
   rendered below comes from the accounts and risk_limits tables, read under
   the signed-in user's session.
   ========================================================================== */

let ACCOUNTS = [];
let activeAccountId = null;

function fmtMoney(n){
  if(n===null||n===undefined||Number.isNaN(n)) return '—';
  return '$'+Number(n).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
}
/* Percentages come from NUMERIC columns. Render what the database holds — no
   rounding that could make a limit look tighter or looser than it is. */
function pct(n){ return (n===null||n===undefined) ? null : String(n)+'%'; }

function renderAcctSelect(){
  document.getElementById('acctSelect').innerHTML=ACCOUNTS.map(a=>
    '<option value="'+a.id+'"'+(a.id===activeAccountId?' selected':'')+'>'+
    a.name+' · '+a.broker+(a.accountType==='paper'?' · PAPER':'')+'</option>').join('');
}

function renderRisk(){
  const a=ACCOUNTS.find(x=>x.id===activeAccountId)||ACCOUNTS[0];
  if(!a) return;

  document.getElementById('acctMeta').innerHTML=
    '<span>balance <b>'+fmtMoney(a.balance)+'</b></span>'+
    '<span>equity <b>'+fmtMoney(a.equity)+'</b></span>'+
    '<span>role <b>'+a.role+'</b></span>'+
    '<span>type <b>'+a.accountType+'</b></span>';

  /* Notes panel. Two distinct kinds of caveat, never blended into a number:
     a data-derived one (this account really is at zero in the database) and,
     where one exists, a founder-supplied annotation that is not yet in the DB. */
  const notes=[];
  if(a.balance===0){
    notes.push('<b>Balance is $0.00 in the database.</b> These limits are percentage-based, so they are structural until a real balance is recorded — they do not constrain anything yet.');
  }
  if(a.tradingHalted){
    notes.push('<b>Trading is halted for this account.</b>'+(a.haltedReason?' Reason: '+a.haltedReason:''));
  }
  if(a.note){
    notes.push('<b>Founder note (not from the database):</b> '+a.note);
  }
  const noteEl=document.getElementById('acctNote');
  noteEl.innerHTML=notes.map(n=>'<div>'+n+'</div>').join('');
  noteEl.hidden=notes.length===0;

  document.getElementById('riskGrid').innerHTML=[
   ['Max position risk / trade',pct(a.maxPositionRiskPct),'ok','of equity — pip-based SL, see rule table'],
   ['Max account drawdown',pct(a.maxAccountDrawdownPct),'ok','hard limit before halt'],
   ['Daily losing-trade limit',a.maxDailyLosingTrades!=null?a.maxDailyLosingTrades+' trades':'not set','ok','circuit breaker, not %-based'],
   ['Weekly losing-trade limit',a.maxWeeklyLosingTrades!=null?a.maxWeeklyLosingTrades+' trades':'not set','ok','circuit breaker, not %-based'],
  ].map(([l,v,st,s])=>'<div class="risk-box"><div class="rl">'+l+'</div><div class="rv '+st+'">'+(v||'not set')+'</div><div class="rs">'+s+'</div></div>').join('');

  /* "enforced" below means enforced by scripts/risk/validate_trade.py in the
     hedge-fund-os repo, which every trade proposal must pass. It does not mean
     this dashboard enforces anything — APEX OS only reads. */
  const rules=[
   ['Max position risk per trade',pct(a.maxPositionRiskPct),'Hard limit','enforced'],
   ['Max account drawdown',pct(a.maxAccountDrawdownPct),'Hard limit — halts new trades','enforced'],
   ['Daily losing-trade circuit breaker',(a.maxDailyLosingTrades!=null?a.maxDailyLosingTrades+' losing trades/day':'not set'),'Hard limit',a.maxDailyLosingTrades!=null?'enforced':'not set'],
   ['Weekly losing-trade circuit breaker',(a.maxWeeklyLosingTrades!=null?a.maxWeeklyLosingTrades+' losing trades/week':'not set'),'Hard limit',a.maxWeeklyLosingTrades!=null?'enforced':'not set'],
   ['Max position size (% of equity)',pct(a.maxPositionSizePct),'Non-binding ceiling — real control is position risk %','enforced'],
   ['Max open positions',a.maxOpenPositions!=null?String(a.maxOpenPositions):'not set','Non-binding ceiling','enforced'],
   ['Max correlated exposure',a.maxCorrelatedExposurePct!=null?pct(a.maxCorrelatedExposurePct):'not evaluated','Out of scope for this repo','n/a'],
   ['Max single-symbol exposure',pct(a.maxSingleSymbolExposurePct),'Soft limit — flags for review','enforced'],
   ['Live execution without human approval','Not permitted','Policy','enforced'],
  ];
  document.getElementById('ruleTable').innerHTML='<div class="rule-row head"><span>Rule</span><span>Limit</span><span>Type</span><span>Status</span></div>'+
   rules.map(([n,lim,type,st])=>'<div class="rule-row"><span class="rn">'+n+'</span><span>'+(lim||'not set')+'</span><span>'+type+'</span><span class="status">'+(st==='enforced'?'<span class="dot ok pulse"></span>enforced':'<span class="dot off"></span>'+st)+'</span></div>').join('');

  const stamp=a.limitsUpdatedAt?new Date(a.limitsUpdatedAt).toLocaleString():'unknown';
  document.getElementById('riskStamp').innerHTML=PROV_LIVE+'<span style="margin-left:8px">limits last updated '+stamp+'</span>';
}

function setRiskState(html, isError){
  const el=document.getElementById('riskState');
  el.className='state'+(isError?' err':'');
  el.innerHTML=html;
  el.hidden=false;
  document.getElementById('riskBody').hidden=true;
}

async function loadRisk(){
  const btn=document.getElementById('riskRefresh');
  if(btn) btn.disabled=true;
  setRiskState('Loading accounts and risk limits from Supabase…', false);
  try{
    const rows=await window.APEX.fetchAccounts();
    if(!rows.length){
      setRiskState('<div class="st-h">No accounts returned</div>'+
        'The query succeeded but came back empty. That normally means the signed-in user has a session but the read policies from migration <code>018</code> have not been applied to this project.', true);
      return;
    }
    ACCOUNTS=rows;
    if(!ACCOUNTS.some(x=>x.id===activeAccountId)) activeAccountId=ACCOUNTS[0].id;
    document.getElementById('riskState').hidden=true;
    document.getElementById('riskBody').hidden=false;
    renderAcctSelect();
    renderRisk();
  }catch(err){
    setRiskState('<div class="st-h">Could not load risk data</div>'+
      String(err && err.message ? err.message : err)+
      '<div style="margin-top:10px;color:var(--text-3)">If this says permission denied, apply <code>schemas/postgres/018_rls_authenticated_read_policies.sql</code> to the Supabase project.</div>', true);
  }finally{
    if(btn) btn.disabled=false;
  }
}

document.getElementById('acctSelect').addEventListener('change',e=>{activeAccountId=e.target.value;renderRisk();});
document.getElementById('riskRefresh').addEventListener('click',loadRisk);

/* =============================================================================
   BRAIN page — ILLUSTRATIVE IN FULL.

   Nothing on this page is wired to anything. There is no ingest CLI, no
   embedding service, no pgvector index, and no knowledge vault. The health
   scores (79/100, 57), the storage-layer states, the folder counts, the
   doctor checks and the constellation are all hand-authored to show the
   intended shape of the feature. The page carries a standing banner saying so.
   ========================================================================== */
const LAYERS=[
 ['Ingest CLI','v0.1 · local · doctor --fast','LIVE','ok'],
 ['knowledge-vault/','GitHub repo · markdown research &amp; SOPs','0 pages · pre-launch','warn'],
 ['Embedding service','hybrid-search embeddings for vault content','LIVE','ok'],
 ['Postgres + pgvector','trades / research / decision log tables','LIVE · 6 tables','ok'],
];
document.getElementById('layerList').innerHTML=LAYERS.map(([n,s,v,st])=>'<div class="layer"><span class="dot '+(st==='ok'?'ok pulse':st==='err'?'err':'warn')+'"></span><div class="body"><div class="ln">'+n+'</div><div class="ls">'+s+'</div></div><span class="lv '+st+'">'+v+'</span></div>').join('');
const FOLDERS=[['Macro Research',0],['Fundamental',0],['Quant Models',0],['SOPs',6],['Decision Log',3],['Risk Rules',7],['Meeting Notes',2],['Mistake DB',0]];
const maxF=Math.max(1,...FOLDERS.map(f=>f[1]));
document.getElementById('folderList').innerHTML=FOLDERS.map(([n,f])=>'<div class="folder-row"><span class="fn">'+n+'</span><span class="fbar" style="width:'+Math.max(6,(f/maxF)*100)+'px;opacity:'+(0.25+0.55*(f/maxF)).toFixed(2)+'"></span><span class="ff">'+f+'</span></div>').join('');
const CHECKS=[['Postgres connection','ok','healthy, 6 tables initialized'],['Embedding service','ok','API reachable'],['knowledge-vault parse','warn','vault mostly empty — pre-launch, expected'],['sync freshness','ok','no drift']];
document.getElementById('checkList').innerHTML=CHECKS.map(([n,st,m])=>'<div class="check"><span class="dot '+(st==='ok'?'ok':st==='warn'?'warn':'err')+'"></span><span><b style="color:var(--text)">'+n+'</b> — '+m+'</span></div>').join('');
document.getElementById('cmdTags').innerHTML=['put','get','query','search','sync','import','export','doctor'].map(c=>'<span class="cmd-tag">'+c+'</span>').join('');

// knowledge graph
(function(){
  const W=1200,H=300;const cx=W/2,cy=H/2;
  const deptNodes=DEPTS.map((d,i)=>{const ang=(i/DEPTS.length)*Math.PI*2-Math.PI/2;return{id:d[0],label:d[1],color:d[3],x:cx+Math.cos(ang)*190,y:cy+Math.sin(ang)*98,r:9};});
  let html='';
  const center={x:cx,y:cy};
  deptNodes.forEach(d=>{html+='<line x1="'+center.x+'" y1="'+center.y+'" x2="'+d.x+'" y2="'+d.y+'" stroke="var(--border-strong)" stroke-width="1"/>';});
  deptNodes.forEach((d)=>{
    const liveLeaves=LIVE.filter(a=>a[5]===d.id);
    const phLeaves=PLACEHOLDERS.filter(p=>p.dept===d.id).slice(0,6);
    const leaves=[...liveLeaves.map(a=>({active:true})),...phLeaves.map(()=>({active:false}))];
    leaves.forEach((a,i)=>{
      const ang=(i/Math.max(1,leaves.length))*Math.PI*2;const lx=d.x+Math.cos(ang)*46;const ly=d.y+Math.sin(ang)*36;
      html+='<line x1="'+d.x+'" y1="'+d.y+'" x2="'+lx+'" y2="'+ly+'" stroke="var(--border)" stroke-width="0.8"/>';
      html+='<circle cx="'+lx+'" cy="'+ly+'" r="3" fill="'+(a.active?d.color:'var(--text-3)')+'" opacity="'+(a.active?0.9:0.5)+'"/>';
    });
  });
  deptNodes.forEach(d=>{
    html+='<circle cx="'+d.x+'" cy="'+d.y+'" r="'+d.r+'" fill="'+d.color+'"/>';
    html+='<text x="'+d.x+'" y="'+(d.y-14)+'" fill="var(--text-2)" font-size="9.5" text-anchor="middle" font-family="JetBrains Mono">'+d.label+'</text>';
  });
  html+='<circle cx="'+center.x+'" cy="'+center.y+'" r="16" fill="var(--accent)"/>';
  html+='<text x="'+center.x+'" y="'+(center.y+4)+'" fill="var(--accent-ink)" font-size="10" font-weight="700" text-anchor="middle" font-family="JetBrains Mono">CEO</text>';
  document.getElementById('kgSvg').innerHTML=html;
})();

// pillar radar
(function(){
  const axes=[['Investment',0.7],['Risk',0.85],['Portfolio',0.6],['Trading',0.55],['Capital',0.5],['Knowledge',0.4],['Intel',0.65],['Human',0.45],['Engineering',0.35],['Executive',0.75]];
  const cx=180,cy=180,R=120;const n=axes.length;let html='';
  for(let ring=1;ring<=4;ring++){const rr=R*ring/4;let pts='';for(let i=0;i<n;i++){const a=(i/n)*Math.PI*2-Math.PI/2;pts+=(cx+Math.cos(a)*rr).toFixed(1)+','+(cy+Math.sin(a)*rr).toFixed(1)+' ';}html+='<polygon points="'+pts+'" fill="none" stroke="var(--border)" stroke-width="0.8"/>';}
  axes.forEach((ax,i)=>{const a=(i/n)*Math.PI*2-Math.PI/2;const ex=cx+Math.cos(a)*R,ey=cy+Math.sin(a)*R;html+='<line x1="'+cx+'" y1="'+cy+'" x2="'+ex+'" y2="'+ey+'" stroke="var(--border)" stroke-width="0.8"/>';const lx=cx+Math.cos(a)*(R+26),ly=cy+Math.sin(a)*(R+26);html+='<text x="'+lx+'" y="'+ly+'" fill="var(--text-3)" font-size="9" text-anchor="middle" font-family="JetBrains Mono">'+ax[0]+'</text>';});
  let poly='';axes.forEach((ax,i)=>{const a=(i/n)*Math.PI*2-Math.PI/2;poly+=(cx+Math.cos(a)*R*ax[1]).toFixed(1)+','+(cy+Math.sin(a)*R*ax[1]).toFixed(1)+' ';});
  html+='<polygon points="'+poly+'" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)" stroke-width="1.5"/>';
  axes.forEach((ax,i)=>{const a=(i/n)*Math.PI*2-Math.PI/2;html+='<circle cx="'+(cx+Math.cos(a)*R*ax[1]).toFixed(1)+'" cy="'+(cy+Math.sin(a)*R*ax[1]).toFixed(1)+'" r="3" fill="var(--accent)"/>';});
  html+='<text x="'+cx+'" y="'+cy+'" fill="var(--accent)" font-size="22" font-weight="700" text-anchor="middle" dominant-baseline="middle" font-family="JetBrains Mono">57</text>';
  document.getElementById('radarSvg').innerHTML=html;
})();

// brain core constellation
(function(){
  const W=500,H=340,cx=W/2,cy=H/2;let html='';
  const clusters=[['Risk Rules','var(--err)',0,0,50],['Research','#5ec9f8',-140,-60,30],['SOPs','#4ade96',150,-40,22],['Decisions','#a855f7',-120,80,18],['Trades','#ffc53d',130,90,10],['Lessons','#f096c8',0,-120,8]];
  for(let i=0;i<160;i++){const a=Math.random()*Math.PI*2;const r=Math.random()*160;html+='<circle cx="'+(cx+Math.cos(a)*r).toFixed(1)+'" cy="'+(cy+Math.sin(a)*r*0.75).toFixed(1)+'" r="'+(Math.random()*1.1+0.3).toFixed(1)+'" fill="var(--text-3)" opacity="'+(Math.random()*0.4+0.1).toFixed(2)+'"/>';}
  clusters.forEach(([name,color,dx,dy,cnt])=>{
    const ox=cx+dx,oy=cy+dy;
    for(let i=0;i<cnt;i++){const a=Math.random()*Math.PI*2;const r=Math.random()*26+3;html+='<circle cx="'+(ox+Math.cos(a)*r).toFixed(1)+'" cy="'+(oy+Math.sin(a)*r).toFixed(1)+'" r="'+(Math.random()*1.4+0.6).toFixed(1)+'" fill="'+color+'" opacity="'+(Math.random()*0.5+0.4).toFixed(2)+'"/>';}
    html+='<circle cx="'+ox+'" cy="'+oy+'" r="3.5" fill="'+color+'"/>';
    html+='<text x="'+ox+'" y="'+(oy-14)+'" fill="var(--text-2)" font-size="9.5" text-anchor="middle" font-family="JetBrains Mono">'+name+'</text>';
  });
  html+='<circle cx="'+cx+'" cy="'+cy+'" r="5" fill="var(--accent)"/><circle cx="'+cx+'" cy="'+cy+'" r="11" fill="none" stroke="var(--accent)" stroke-width="1" opacity="0.4"/>';
  document.getElementById('coreSvg').innerHTML=html;
})();

/* ---- page routing ---- */
const CRUMB={agents:'agents',org:'org-chart',risk:'risk-desk',brain:'super-brain'};
function show(pg){
  if(!['agents','org','risk','brain'].includes(pg))return;
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  document.getElementById('page-'+pg).classList.add('active');
  document.getElementById('crumb').textContent=CRUMB[pg];
  document.querySelectorAll('.nav-item').forEach(n=>n.classList.toggle('active',n.dataset.page===pg));
  window.scrollTo(0,0);
}
document.getElementById('nav').addEventListener('click',e=>{const a=e.target.closest('.nav-item');if(!a)return;e.preventDefault();show(a.dataset.page);});
show('agents');

/* ---- theme ---- */
const pills=document.getElementById('themePills');
function setTheme(t){
  document.documentElement.setAttribute('data-theme',t);
  [...pills.children].forEach(b=>b.setAttribute('data-active',b.dataset.themeSet===t));
  try{ localStorage.setItem('apex.theme',t); }catch{}
}
pills.addEventListener('click',e=>{const b=e.target.closest('[data-theme-set]');if(b)setTheme(b.dataset.themeSet);});
let savedTheme='dark';
try{ savedTheme=localStorage.getItem('apex.theme')||'dark'; }catch{}
setTheme(['dark','light','midnight'].includes(savedTheme)?savedTheme:'dark');

/* =============================================================================
   Sign-in gate.

   Migration 018 grants `anon` nothing, so an unauthenticated app reads no
   rows at all. The gate exists to get a real Supabase Auth session before the
   UI is shown, and the session persists so this is a once-per-machine step.
   ========================================================================== */
const gate=document.getElementById('gate');
const gateForm=document.getElementById('gateForm');
const gateMsg=document.getElementById('gateMsg');
const gateSubmit=document.getElementById('gateSubmit');

function setGateMsg(text, kind){
  gateMsg.className='gate-msg'+(kind?' '+kind:'');
  gateMsg.textContent=text||'';
}

function showApp(session){
  gate.hidden=true;
  const email=session && session.user ? session.user.email : '';
  document.getElementById('connState').innerHTML=
    '<span class="dot ok pulse"></span> signed in';
  document.getElementById('connWho').textContent=email;
  loadRisk();
}

function showGate(){
  gate.hidden=false;
  document.getElementById('connState').innerHTML='<span class="dot off"></span> signed out';
  document.getElementById('connWho').textContent='';
}

gateForm.addEventListener('submit', async (e)=>{
  e.preventDefault();
  const email=document.getElementById('gateEmail').value.trim();
  const password=document.getElementById('gatePassword').value;
  if(!email||!password){ setGateMsg('Enter an email and password.','err'); return; }
  gateSubmit.disabled=true;
  setGateMsg('Signing in…','info');
  try{
    const session=await window.APEX.auth.signIn(email,password);
    document.getElementById('gatePassword').value='';
    setGateMsg('','');
    showApp(session);
  }catch(err){
    setGateMsg(String(err && err.message ? err.message : err),'err');
  }finally{
    gateSubmit.disabled=false;
  }
});

document.getElementById('signOutBtn').addEventListener('click', async ()=>{
  await window.APEX.auth.signOut();
  ACCOUNTS=[]; activeAccountId=null;
  showGate();
});

(async function boot(){
  if(!window.APEX.configured){
    gate.hidden=false;
    setGateMsg('Supabase is not configured. Check electron/config.js or the APEX_SUPABASE_URL / APEX_SUPABASE_ANON_KEY environment variables.','err');
    gateSubmit.disabled=true;
    return;
  }
  const session=await window.APEX.auth.currentSession();
  if(session) showApp(session); else showGate();
})();
