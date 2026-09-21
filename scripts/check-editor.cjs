// Usage: PLAYWRIGHT_MODULE=... CHROMIUM_PATH=... node scripts/check-editor.cjs
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../EventVision/Web');
const points=[{x:2,y:-1.2,z:3},{x:2,y:-1.2,z:7},{x:-1,y:-1.2,z:7},{x:-1,y:-1.2,z:3}];
const canonical=[{x:0,y:0,z:0},{x:4,y:0,z:0},{x:4,y:0,z:3},{x:0,y:0,z:3}];
const id=i=>`corner_${String(i+1).padStart(2,'0')}`;
const scan={schema:'eventvision_scan_result',version:1,scan_id:'native-fixture',created_at:'2026-09-21T00:00:00Z',
  app_protocol:'EventVision_v10_5_shared_scan_contract',source:{provider:'arkit',platform:'ios',mode:'fresh_scan'},units:'meters',
  coordinate_system:{handedness:'right_handed',canonical_origin:'corner_01',canonical_x_axis:'corner_01_to_corner_02',vertical_axis:'Y',floor_plane:'XZ',canonical_floor_y_m:0},
  tracking:{reference_space:'arkit_world',floor_y_m:-1.2,device_pose_at_finish:null,projection_at_finish:null},
  room:{closed:true,area_m2:12,perimeter_m:14,corners:points.map((p,i)=>({id:id(i),order:i+1,position_m:canonical[i],tracking_position_m:p})),
    walls:points.map((p,i)=>({id:`wall_${String(i+1).padStart(2,'0')}`,from_corner_id:id(i),to_corner_id:id((i+1)%4),length_m:i%2===0?4:3}))},
  quality:{corner_count:4,floor_locked:true,metric_scale:true}};
(async()=>{
  const server=http.createServer((req,res)=>{
    const relative=req.url==='/'?'index.html':req.url.slice(1);
    const file=path.resolve(root,relative);
    if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
    try {res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':'text/html');res.end(fs.readFileSync(file));}
    catch {res.writeHead(404).end();}
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  let browser;
  try{
    browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH,headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
    const page=await browser.newPage({viewport:{width:390,height:740},isMobile:true,hasTouch:true});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.route('https://**',route=>route.abort()); // Editor must work with no external dependencies.
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    await page.waitForFunction(()=>!!window.EventVisionScan);
    const reply=await page.evaluate(scan=>window.EventVisionScan.receive(scan),scan);
    assert.equal(reply.accepted,true);
    assert.equal(await page.locator('#cornerMetric').textContent(),'4');
    assert.match(await page.locator('#areaMetric').textContent(),/12\.00/);
    await page.locator('#addFurniture').click();
    assert.equal(await page.locator('#furnitureLayer').locator(':scope > *').count(),1);
    assert.equal(await page.locator('#screenshotMode').isVisible(),false);
    const invalid=structuredClone(scan);invalid.room.corners[1].position_m.x=NaN;
    const bad=await page.evaluate(value=>window.EventVisionScan.receive(value),invalid);
    assert.equal(bad.accepted,false);
    assert.deepEqual(errors,[]);
    console.log('PASS: offline editor initialization, native contract import, room metrics, add chair, unsupported control hidden, invalid scan rejection, no page errors.');
  }finally{if(browser)await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
