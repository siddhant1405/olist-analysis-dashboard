const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = __dirname;
const report = path.join(root, 'olist dashboard pbip.Report');
const pagesRoot = path.join(report, 'definition', 'pages');
const schema = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json';
const id = () => crypto.randomBytes(10).toString('hex');
const lit = value => ({ expr: { Literal: { Value: value } } });
const color = hex => ({ solid: { color: lit(`'${hex}'`) } });
const column = (Entity, Property) => ({ Column: { Expression: { SourceRef: { Entity } }, Property } });
const measure = (Entity, Property) => ({ Measure: { Expression: { SourceRef: { Entity } }, Property } });
const year = () => ({ HierarchyLevel: { Expression: { Hierarchy: { Expression: { PropertyVariationSource: { Expression: { SourceRef: { Entity: 'dev fact_orders' } }, Name: 'Variation', Property: 'order_purchase_at' } }, Hierarchy: 'Date Hierarchy' } }, Level: 'Year' } });
const field = (expr, queryRef, nativeQueryRef, active) => ({ field: expr, queryRef, nativeQueryRef, ...(active ? { active: true } : {}) });
// Field shorthand for the story pages: c = column, m = measure.
const c = (e, p) => ({ expr: column(e, p), ref: `${e}.${p}`, name: p });
const m = (e, p) => ({ expr: measure(e, p), ref: `${e}.${p}`, name: p });
const proj = (f, active) => field(f.expr, f.ref, f.name, active);
const sortBy = (f, direction) => ({ sort: [{ field: f.expr, direction }], isDefaultSort: true });
const write = (file, value) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n'); };
const pos = (x,y,width,height,z) => ({ x,y,width,height,z,tabOrder:z });
function base(type, position, queryState = {}) { return { $schema:schema, name:id(), position, visual:{ visualType:type, ...(Object.keys(queryState).length ? {query:{queryState}} : {}), visualContainerObjects:{background:[{properties:{show:lit('false')}}]}, drillFilterOtherVisuals:true } }; }
function titled(v, title) { v.visual.visualContainerObjects.title=[{properties:{show:lit('true'),text:lit(`'${title}'`),fontFamily:lit("'Segoe UI'"),fontSize:lit('12D'),fontColor:color('#1D1C1C')}}]; return v; }
function textbox(text, p, size=20, muted=false) { const v=base('textbox',p); v.visual.objects={general:[{properties:{paragraphs:[{textRuns:[{value:' '},{value:text,textStyle:{fontWeight: muted?'normal':'bold',fontFamily:'Constantia',fontSize:`${size}pt`,color:muted?'#6C6C6C':'#1D1C1C'}}]}]}}]}; return v; }
function note(heading, body, p) { const v=base('textbox',p); const run=(value,bold,size,hex)=>({textRuns:[{value,textStyle:{fontWeight:bold?'bold':'normal',fontFamily:'Segoe UI',fontSize:`${size}pt`,color:hex}}]}); v.visual.objects={general:[{properties:{paragraphs:[run(heading,true,12,'#1D1C1C'),run(body,false,10,'#4A4A4A')]}}]}; return v; }
function shape(p) { const v=base('shape',p); v.visual.objects={shape:[{properties:{tileShape:lit("'rectangleRounded'"),rectangleRoundedCurve:lit('12L')}}],outline:[{properties:{show:lit('false')}}],fill:[{properties:{fillColor:color('#F5F4F1')},selector:{id:'default'}}]}; return v; }
function card(label, entity, measureName, p) { const v=base('card',p,{Values:{projections:[field(measure(entity,measureName),`${entity}.${measureName}`,measureName)]}}); v.visual.objects={labels:[{properties:{fontSize:lit('18D'),bold:lit('true'),color:color('#1D1C1C')}}]}; return v; }
// series (optional) splits each category by a column, e.g. a stacked column chart. Multi-series charts keep theme colours.
function chart(type, title, categoryExpr, categoryRef, categoryName, measures, p, sort, series) { const state={Category:{projections:[field(categoryExpr,categoryRef,categoryName,true)]},Y:{projections:measures.map(([e,m])=>field(measure(e,m),`${e}.${m}`,m))}}; if(series) state.Series={projections:[proj(series,true)]}; const v=base(type,p,state); if(sort) v.visual.query.sortDefinition=sort; v.visual.objects={categoryAxis:[{properties:{labelColor:color('#1D1C1C')}}]}; if(!series && measures.length===1) v.visual.objects.dataPoint=[{properties:{defaultColor:color('#313D44')}}]; return titled(v,title); }
function matrix(title, rows, columns, values, p, totals=true) { const q={Rows:{projections:rows.map(([e,c])=>field(column(e,c),`${e}.${c}`,c,true))},Values:{projections:values.map(([e,m])=>field(measure(e,m),`${e}.${m}`,m))}}; if(columns) q.Columns={projections:columns.map(([e,c])=>field(column(e,c),`${e}.${c}`,c,true))}; const v=base('pivotTable',p,q); v.visual.objects={columnHeaders:[{properties:{autoSizeColumnWidth:lit('true'),columnAdjustment:lit("'growToFit'")}}],values:[{properties:{fontSize:lit('10D')}}]}; if(!totals) v.visual.objects.subTotals=[{properties:{rowSubtotals:lit('false'),columnSubtotals:lit('false')}}]; return titled(v,title); }
function table(title, fields, p, sort) { const v=base('tableEx',p,{Values:{projections:fields.map(f=>proj(f))}}); if(sort) v.visual.query.sortDefinition=sort; v.visual.objects={values:[{properties:{fontSize:lit('10D')}}],columnHeaders:[{properties:{fontSize:lit('10D')}}]}; return titled(v,title); }
function slicer(expr, ref, name, p) { const v=base('advancedSlicerVisual',p,{Values:{projections:[field(expr,ref,name,true)]}}); v.visual.objects={shapeCustomRectangle:[{properties:{tileShape:lit("'rectangle'")},selector:{id:'default'}}]}; return v; }
// A row of KPI tiles: [label, entity, measure] spread evenly across the 940px content width.
function kpis(list, y=88) { const gap=10, w=(940-gap*(list.length-1))/list.length; return list.flatMap(([label,e,mName],i)=>{ const x=10+i*(w+gap); return [shape(pos(x,y,w,80,1000+i)), textbox(label,pos(x+8,y+2,w-16,34,20000+i),11,true), card(label,e,mName,pos(x+8,y+36,w-16,36,10000+i))]; }); }
function add(pageId, displayName, visuals) { const pageDir=path.join(pagesRoot,pageId); if(path.dirname(pageDir)!==pagesRoot) throw new Error('Refusing to clear a page outside the report pages directory'); fs.rmSync(pageDir,{recursive:true,force:true}); const page={ $schema:'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json', name:pageId, displayName, displayOption:'FitToPage', height:720, width:960, objects:{background:[{properties:{color:color('#FFFEFB'),transparency:lit('0D')}}]} }; write(path.join(pageDir,'page.json'),page); visuals.forEach(v=>write(path.join(pageDir,'visuals',v.name,'visual.json'),v)); }
const fact='dev fact_orders', items='dev fact_order_items';
const product='dev dim_product', summary='dev customer_summary', cohorts='dev customer_cohort_retention', rfm='dev customer_rfm', sellers='dev seller_scorecard';
const regions='dev region_summary', breakeven='dev freight_subsidy_breakeven';
const categoryColumn=column(items,'product_category_name_english');
const month=c(fact,'purchase_month');
// Page footnotes: small muted text along the bottom edge.
const footnote=(text,z)=>textbox(text,pos(12,684,936,30,z),8,true);

// 1. Executive summary: how the business is doing and the four things holding it back.
const exec=[]; exec.push(textbox('Olist Executive Summary',pos(10,22,600,40,19000))); exec.push(textbox('Delivery, retention, regional and seller metrics cover delivered orders from Jan 2017 to Aug 2018.',pos(10,56,700,26,19001),10,true));
exec.push(...kpis([['Revenue (GMV)',fact,'Revenue'],['Customers',fact,'Unique Customers'],['Repeat Rate (180d)',summary,'Repeat Rate 180d'],['Late Delivery Rate',fact,'Late Delivery Rate'],['Avg Review',product,'Avg review score'],['1-2 Star Review Rate',fact,'Bad Review Rate']]));
[['1. Growth is all new customers','98% of revenue comes from first purchases; only 2.0% of customers buy again within 180 days.'],
 ['2. Olist barely reaches the North and Northeast','75 customers per 100k people in the Southeast vs 16 in the Northeast and 10 in the North. Those regions have 2% of sellers, pay more freight and get up to twice the late deliveries.'],
 ['3. Bad reviews come from fulfilment','Late and undelivered orders cause 43% of 1-2 star reviews. On-time orders with several items or sellers are 3-6x more likely to get one than single-item orders.'],
 ['4. Local sellers deliver better','Within the same state and category, local sellers are late 3.4% vs 8.1% from Sao Paulo. 54 high-risk sellers cause 11.4% of late orders from 4.5% of volume.']
].forEach(([h,b],i)=>{ const x=10+i*237.5; exec.push(shape(pos(x,183,227.5,150,1100+i))); exec.push(note(h,b,pos(x+6,187,215.5,142,21000+i))); });
exec.push(chart('clusteredColumnChart','Delivered orders by month',month.expr,month.ref,month.name,[[fact,'Delivered Orders']],pos(10,350,455,350,3000),sortBy(month,'Ascending')));
exec.push(chart('lineChart','Late delivery rate by month',month.expr,month.ref,month.name,[[fact,'Late Delivery Rate']],pos(495,350,455,350,4000),sortBy(month,'Ascending')));

// 2. Revenue & growth: where revenue comes from, and how geography and freight shape it.
const rev=[]; rev.push(textbox('Revenue & Growth',pos(10,22,600,50,19000)));
rev.push(...kpis([['Revenue (GMV)',fact,'Revenue'],['Orders',fact,'Orders'],['Revenue from New Customers',fact,'New Customer Revenue Share'],['Freight % of Item Value',fact,'Freight % of Item Value'],['Orders from Local Sellers',fact,'Local Seller Order Share']]));
const customerType=c(fact,'customer_type'), region=c(regions,'region'), valueBand=c(breakeven,'order_value_band');
rev.push(chart('columnChart','Revenue by month: new vs returning customers',month.expr,month.ref,month.name,[[fact,'Revenue']],pos(10,178,455,160,3000),sortBy(month,'Ascending'),customerType));
rev.push(chart('clusteredBarChart','Revenue by product category',categoryColumn,`${items}.product_category_name_english`,'product_category_name_english',[[fact,'Revenue']],pos(495,178,455,160,4000),sortBy(m(fact,'Revenue'),'Descending')));
rev.push(chart('clusteredBarChart','Share of population, customers and sellers by region',region.expr,region.ref,region.name,[[regions,'Share of Population'],[regions,'Share of Customers'],[regions,'Share of Sellers']],pos(10,346,455,160,5000),sortBy(region,'Ascending')));
rev.push(table('Regional reach and cost to serve',[region,m(regions,'Customers per 100k'),m(regions,'Region Freight Share'),m(regions,'Region Late Rate'),m(regions,'Region Avg Review')],pos(495,346,455,160,6000),sortBy(region,'Ascending')));
rev.push(matrix('Late rate by seller location',[[fact,'customer_region']],[[fact,'seller_origin']],[[fact,'Late Delivery Rate']],pos(10,514,455,166,7000),false));
rev.push(chart('lineChart','Freight share vs subsidy break-even, by order value',valueBand.expr,valueBand.ref,valueBand.name,[[breakeven,'Band Freight Share'],[breakeven,'Break-even at 10% Commission'],[breakeven,'Break-even at 15% Commission'],[breakeven,'Break-even at 20% Commission']],pos(495,514,455,166,8000),sortBy(valueBand,'Ascending')));
rev.push(footnote('A freight subsidy pays off only where freight share is below the break-even line (|elasticity| x commission). Elasticity is estimated at -0.52 from route-level freight changes (range about -0.1 to -1.0); commission is assumed. Population: IBGE 2022 Census.',23000));

// 3. Customers & retention: how few return, what a late first order does, and what to do with each segment.
const cust=[]; cust.push(textbox('Customers & Retention',pos(10,22,600,50,19000)));
cust.push(...kpis([['Customers',summary,'Purchasing Customers'],['One-time Customers',summary,'One-time Customer Share'],['Repeat Rate (180d)',summary,'Repeat Rate 180d'],['Median Days to 2nd Purchase',summary,'Median Days to 2nd Purchase']]));
cust.push(matrix('Cohort retention: share buying again, by months since first purchase',[[cohorts,'cohort_label']],[[cohorts,'month_number']],[[cohorts,'Cohort Retention Rate']],pos(10,185,455,260,3000),false));
const segment=c(rfm,'rfm_segment'), firstDelivery=c(summary,'first_order_delivery');
cust.push(chart('clusteredBarChart','Segment share of customers vs revenue',segment.expr,segment.ref,segment.name,[[rfm,'RFM Customer Share'],[rfm,'RFM Revenue Share']],pos(495,185,455,260,4000),sortBy(segment,'Ascending')));
cust.push(table('Segment playbook',[segment,m(rfm,'Eligible Customer Count'),m(rfm,'RFM Customer Share'),m(rfm,'RFM Revenue Share'),m(rfm,'Avg Customer Value'),c(rfm,'recommended_action')],pos(10,465,640,240,5000),sortBy(segment,'Ascending')));
cust.push(chart('clusteredColumnChart','Repeat rate (180d) by first-order delivery',firstDelivery.expr,firstDelivery.ref,firstDelivery.name,[[summary,'Repeat Rate 180d']],pos(660,465,290,240,6000)));

// 4. Delivery & customer experience: where delivery fails and what drives 1-2 star reviews.
const del=[]; del.push(textbox('Delivery & Customer Experience',pos(10,22,600,50,19000)));
del.push(...kpis([['Late Delivery Rate',fact,'Late Delivery Rate'],['1-2 Star Review Rate',fact,'Bad Review Rate'],['Avg Review (On Time)',fact,'Avg Review (On Time)'],['Avg Review (Late)',fact,'Avg Review (Late)'],['Avg Promised Days',fact,'Avg Promised Days'],['Avg Actual Days',fact,'Avg Actual Delivery Days']]));
const timing=c(fact,'delivery_timing_bucket'), state=c(fact,'customer_state'), route=c(fact,'shipping_route'), experience=c(fact,'experience_group');
del.push(table('What drives 1-2 star reviews',[experience,m(fact,'Bad Review Rate'),m(fact,'Share of Bad Reviews')],pos(10,185,455,170,3000),sortBy(experience,'Ascending')));
del.push(chart('clusteredColumnChart','Average review by delivery timing',timing.expr,timing.ref,timing.name,[[product,'Avg review score']],pos(10,365,455,170,4000),sortBy(timing,'Ascending')));
del.push(chart('lineChart','Late delivery rate by month',month.expr,month.ref,month.name,[[fact,'Late Delivery Rate']],pos(10,545,455,160,5000),sortBy(month,'Ascending')));
del.push(chart('clusteredBarChart','Late rate by customer state',state.expr,state.ref,state.name,[[fact,'Late Delivery Rate']],pos(495,185,250,520,6000),sortBy(m(fact,'Late Delivery Rate'),'Descending')));
del.push(chart('clusteredColumnChart','Same-state vs cross-state',route.expr,route.ref,route.name,[[fact,'Late Delivery Rate']],pos(755,185,195,250,7000)));
del.push(note('Reading this page','Late and undelivered orders are the biggest source of 1-2 star reviews. Orders split across several sellers get one 47% of the time even when on time, likely because parcels arrive separately.',pos(755,445,195,260,21000)));

// 5. Seller performance: is lateness concentrated, and which sellers to act on.
const sel=[]; sel.push(textbox('Seller Performance',pos(10,22,600,50,19000)));
sel.push(...kpis([['Sellers',sellers,'Scored Sellers'],['High-Risk Sellers',sellers,'High-Risk Sellers'],['Seller Late Rate',sellers,'Seller Late Rate'],['Late Handoff to Carrier',fact,'Seller Handoff Late Rate'],['Seller Avg Review',sellers,'Seller Avg Review']]));
const tier=c(sellers,'performance_tier'), sellerState=c(sellers,'seller_state'), lateOrders=c(sellers,'late_orders');
sel.push(table('Seller tiers (High risk = 30+ orders and 2x platform late rate)',[tier,m(sellers,'Scored Sellers'),m(sellers,'Share of Seller Orders'),m(sellers,'Share of Late Orders'),m(sellers,'Seller Late Rate'),m(sellers,'Seller Avg Review')],pos(10,185,555,200,3000),sortBy(tier,'Ascending')));
sel.push(chart('clusteredBarChart','Late rate by seller state',sellerState.expr,sellerState.ref,sellerState.name,[[sellers,'Seller Late Rate']],pos(585,185,365,200,4000),sortBy(m(sellers,'Seller Late Rate'),'Descending')));
sel.push(table('Sellers with the most late orders',[c(sellers,'seller_id'),sellerState,c(sellers,'delivered_orders'),lateOrders,c(sellers,'late_rate'),c(sellers,'handoff_late_rate'),c(sellers,'avg_review_score'),tier],pos(10,405,940,300,5000),sortBy(lateOrders,'Descending')));

const pageIds={ exec:'c1d2e3f4a5b60718293c', revenue:'b1c2d3e4f5a60718293b', customers:'d1e2f3a4b5c60718293d', delivery:'e1f2a3b4c5d60718293e', sellers:'f1a2b3c4d5e60718293f' };
add(pageIds.exec,'Executive Summary',exec); add(pageIds.revenue,'Revenue & Growth',rev); add(pageIds.customers,'Customers & Retention',cust); add(pageIds.delivery,'Delivery & Customer Experience',del); add(pageIds.sellers,'Seller Performance',sel);
// Retired pages: the hand-built Sales & Growth Overview and Delivery & Seller Performance, and the pricing simulation.
['9b211e8a0d4fd702c22c','7fdd951310cbff28b5a5','a1b2c3d4e5f60718293a'].forEach(p=>fs.rmSync(path.join(pagesRoot,p),{recursive:true,force:true}));
const pagesFile=path.join(pagesRoot,'pages.json'); const pages=JSON.parse(fs.readFileSync(pagesFile)); pages.pageOrder=[pageIds.exec,pageIds.revenue,pageIds.customers,pageIds.delivery,pageIds.sellers]; pages.activePageName=pageIds.exec; write(pagesFile,pages);
