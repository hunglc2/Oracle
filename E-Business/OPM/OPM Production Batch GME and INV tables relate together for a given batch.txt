OPM Production Batch GME and INV tables relate together for a given batch

Oracle Process Manufacturing Process Execution 

OPM Production Batch GME and INV tables relate together for a given batch

The following SQL*Plus queries show how the GME and INV tables relate together for a given batch.

In each statement, please replace the value '12345' with the required Batch Number, and 'PR1' with the relevant Plant Code or Organization.

1) Batch

select gbh.* from gme_batch_header gbh
where gbh.batch_no = '12345'
and gbh.organization_id =
  (select organization_id from org_organization_definitions ood
    where ood.organization_code = 'PR1');   

2) Batch Material Details 


select ood.organization_code, gbh.batch_no, gbh.batch_id, gmd.*
from gme_material_details gmd, gme_batch_header gbh,
 org_organization_definitions ood
where gmd.batch_id = gbh.batch_id
and gbh.batch_no = '12345'
and gbh.organization_id = ood.organization_id
and ood.organization_code = 'PR1'
order by gbh.batch_id, gmd.material_detail_i;


3) Batch Material Transactions Temp


select ood.organization_code, gbh.batch_no, gbh.batch_id, gmd.line_no,
  gmd.material_detail_id, gmd.line_type, mmtt.*
from mtl_material_transactions_temp mmtt, gme_material_details gmd,
   gme_batch_header gbh, org_organization_definitions ood
where mmtt.transaction_source_type_id = 5
and mmtt.trx_source_line_id = gmd.material_detail_id
and mmtt.transaction_source_id = gbh.batch_id
and gmd.batch_id = gbh.batch_id
and gbh.batch_no = '12345'
and gbh.organization_id = ood.organization_id
and ood.organization_code = 'PR1'
order by gbh.batch_id, gmd.line_type, gmd.material_detail_id,
  mmtt.transaction_temp_id;


4) Batch Material Transactions 


select ood.organization_code, gbh.batch_no, gbh.batch_id, gmd.line_no,
gmd.material_detail_id, gmd.line_type, mmt.*
from mtl_material_transactions mmt, gme_material_details gmd, gme_batch_header gbh, org_organization_definitions ood
where mmt.transaction_source_type_id = 5
and mmt.trx_source_line_id = gmd.material_detail_id
and mmt.transaction_source_id = gbh.batch_id
and gmd.batch_id = gbh.batch_id
and gbh.batch_no = '12345'
and gbh.organization_id = ood.organization_id
and ood.organization_code = 'PR1'
order by gbh.batch_id, gmd.line_type, gmd.material_detail_id, mmt.transaction_id;


5) Lot Numbers 


select ood.organization_code, gbh.batch_no, gbh.batch_id, gmd.line_no,
gmd.material_detail_id, gmd.line_type, mtln.*
from mtl_transaction_lot_numbers mtln, mtl_material_transactions mmt,
  gme_material_details gmd, gme_batch_header gbh,
  org_organization_definitions ood
where mtln.transaction_id= mmt.transaction_id
and mmt.transaction_source_type_id = 5
and mmt.trx_source_line_id = gmd.material_detail_id
and gmd.batch_id = gbh.batch_id
and gbh.batch_no = '12345'
and gbh.organization_id = ood.organization_id
and ood.organization_code = 'PR1'
order by gbh.batch_id, gmd.line_type, gmd.material_detail_id, gmd.line_type,
  mmt.transaction_id;


6) Reservations 


select ood.organization_code, gbh.batch_no, gbh.batch_id, gmd.line_no,
  gmd.material_detail_id, gmd.line_type, mr.*
from mtl_reservations mr, gme_material_details gmd, gme_batch_header gbh,
 org_organization_definitions ood
where mr.demand_source_type_id = 5
and mr.demand_source_line_id = gmd.material_detail_id
and gmd.batch_id = gbh.batch_id
and gbh.batch_no = '12345'
and gbh.organization_id = ood.organization_id
and ood.organization_code = 'PR1'
order by gbh.batch_id, gmd.line_type, gmd.material_detail_id, gmd.line_type;


7) Pending Product Lots 

select ood.organization_code, gbh.batch_no, gbh.batch_id, gmd.line_no,
  gmd.material_detail_id, gmd.line_type, gppl.*
from gme_pending_product_lots gppl, gme_material_details gmd, gme_batch_header gbh, org_organization_definitions ood
where gppl.material_detail_id = gmd.material_detail_id
and gmd.batch_id = gbh.batch_id
and gbh.batch_no = '12345'
and gbh.organization_id = ood.organization_id
and ood.organization_code = 'PR1'
order by gbh.batch_id, gmd.line_type, gmd.material_detail_id, gmd.line_type;


8) Requirements 

select ood.organization_code, gbh.batch_no, gbh.batch_id, gbr.*
from gmf_batch_requirements gbr, gme_batch_header gbh,
  org_organization_definitions ood
where gbr.batch_id = gbh.batch_id
and gbh.batch_no = '12345'
and gbh.organization_id = ood.organization_id
and ood.organization_code = 'PR1'
order by gbr.requirement_id;
