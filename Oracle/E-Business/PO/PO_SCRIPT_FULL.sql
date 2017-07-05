1. You need to list out all Internal Requisitions that do not have an associated Internal Sales order.
 
---used to list all Internal Requisitions that do not have an  associated Internal Sales order  
Select RQH.SEGMENT1 REQ_NUM,  
RQL.LINE_NUM,  
RQL.REQUISITION_HEADER_ID ,  
RQL.REQUISITION_LINE_ID,  
RQL.ITEM_ID ,  
RQL.UNIT_MEAS_LOOKUP_CODE ,  
RQL.UNIT_PRICE ,  
RQL.QUANTITY ,  
RQL.QUANTITY_CANCELLED,  
RQL.QUANTITY_DELIVERED ,  
RQL.CANCEL_FLAG ,  
RQL.SOURCE_TYPE_CODE ,  
RQL.SOURCE_ORGANIZATION_ID ,  
RQL.DESTINATION_ORGANIZATION_ID,  
RQH.TRANSFERRED_TO_OE_FLAG  
from  
PO_REQUISITION_LINES_ALL RQL, PO_REQUISITION_HEADERS_ALL RQH  
where  
RQL.REQUISITION_HEADER_ID = RQH.REQUISITION_HEADER_ID  
and RQL.SOURCE_TYPE_CODE = 'INVENTORY'  
and RQL.SOURCE_ORGANIZATION_ID is not null  
and not exists (select 'existing internal order'  
from OE_ORDER_LINES_ALL LIN  
where LIN.SOURCE_DOCUMENT_LINE_ID = RQL.REQUISITION_LINE_ID  
and LIN.SOURCE_DOCUMENT_TYPE_ID = 10)  
ORDER BY RQH.REQUISITION_HEADER_ID, RQL.LINE_NUM;  





2. You want to display what requisition and PO are linked(Relation with Requisition and PO )
-----Relation with Requistion and PO  
select r.segment1 "Req Num",  
       p.segment1 "PO Num"  
from po_headers_all p,   
po_distributions_all d,  
po_req_distributions_all rd,   
po_requisition_lines_all rl,  
po_requisition_headers_all r   
where p.po_header_id = d.po_header_id   
and d.req_distribution_id = rd.distribution_id   
and rd.requisition_line_id = rl.requisition_line_id   
and rl.requisition_header_id = r.requisition_header_id  





3. You need to list out all cancel Requisitions
-----list My cancel Requistion  
select prh.REQUISITION_HEADER_ID,  
      prh.PREPARER_ID ,  
      prh.SEGMENT1 "REQ NUM",  
      trunc(prh.CREATION_DATE),  
      prh.DESCRIPTION,  
      prh.NOTE_TO_AUTHORIZER  
from apps.Po_Requisition_headers_all prh,  
     apps.po_action_history pah   
where Action_code='CANCEL'   
and pah.object_type_code='REQUISITION'   
and pah.object_id=prh.REQUISITION_HEADER_ID   


------------------------------------------------------------------------
4. You need to list those PR which havnt auto created to PO.(Purchase Requisition without a Purchase Order)
 
 
-----list all Purchase Requisition without a Purchase Order that means  a PR has not been autocreated to PO.  
select   
  prh.segment1 "PR NUM",   
  trunc(prh.creation_date) "CREATED ON",   
  trunc(prl.creation_date) "Line Creation Date" ,  
  prl.line_num "Seq #",   
  msi.segment1 "Item Num",   
  prl.item_description "Description",   
  prl.quantity "Qty",   
  trunc(prl.need_by_date) "Required By",   
  ppf1.full_name "REQUESTOR",   
  ppf2.agent_name "BUYER"   
  from   
  po.po_requisition_headers_all prh,   
  po.po_requisition_lines_all prl,   
  apps.per_people_f ppf1,   
  (select distinct agent_id,agent_name from apps.po_agents_v ) ppf2,   
  po.po_req_distributions_all prd,   
  inv.mtl_system_items_b msi,   
  po.po_line_locations_all pll,   
  po.po_lines_all pl,   
  po.po_headers_all ph   
  WHERE   
  prh.requisition_header_id = prl.requisition_header_id   
  and prl.requisition_line_id = prd.requisition_line_id   
  and ppf1.person_id = prh.preparer_id   
  and prh.creation_date between ppf1.effective_start_date and ppf1.effective_end_date   
  and ppf2.agent_id(+) = msi.buyer_id   
  and msi.inventory_item_id = prl.item_id   
  and msi.organization_id = prl.destination_organization_id   
  and pll.line_location_id(+) = prl.line_location_id   
  and pll.po_header_id = ph.po_header_id(+)   
  AND PLL.PO_LINE_ID = PL.PO_LINE_ID(+)   
  AND PRH.AUTHORIZATION_STATUS = 'APPROVED'   
  AND PLL.LINE_LOCATION_ID IS NULL   
  AND PRL.CLOSED_CODE IS NULL   
  AND NVL(PRL.CANCEL_FLAG,'N') <> 'Y'  
  ORDER BY 1,2 


------------------------------------------------------------------------  
5. You need to list all information form PR to PO ...as a requisition moved from different stages till converting into PR. This query capture all details related to that PR to PO.
 
 
----- List and all data entry from PR till PO  
  
select distinct u.description "Requestor",   
porh.segment1 as "Req Number",   
trunc(porh.Creation_Date) "Created On",   
pord.LAST_UPDATED_BY,   
porh.Authorization_Status "Status",   
porh.Description "Description",   
poh.segment1 "PO Number",   
trunc(poh.Creation_date) "PO Creation Date",   
poh.AUTHORIZATION_STATUS "PO Status",   
trunc(poh.Approved_Date) "Approved Date"  
from apps.po_headers_all poh,   
apps.po_distributions_all pod,   
apps.po_req_distributions_all pord,   
apps.po_requisition_lines_all porl,   
apps.po_requisition_headers_all porh,   
apps.fnd_user u   
where porh.requisition_header_id = porl.requisition_header_id   
and porl.requisition_line_id = pord.requisition_line_id   
and pord.distribution_id = pod.req_distribution_id(+)   
and pod.po_header_id = poh.po_header_id(+)   
and porh.created_by = u.user_id  
order by 2   

------------------------------------------------------------------------
6.Identifying all PO's which does not have any PR's
 
 
-----list all Purchase Requisition without a Purchase Order that means  a PR has not been autocreated to PO.  
  select   
  prh.segment1 "PR NUM",   
  trunc(prh.creation_date) "CREATED ON",   
  trunc(prl.creation_date) "Line Creation Date" ,  
  prl.line_num "Seq #",   
  msi.segment1 "Item Num",   
  prl.item_description "Description",   
  prl.quantity "Qty",   
  trunc(prl.need_by_date) "Required By",   
  ppf1.full_name "REQUESTOR",   
  ppf2.agent_name "BUYER"   
  from   
  po.po_requisition_headers_all prh,   
  po.po_requisition_lines_all prl,   
  apps.per_people_f ppf1,   
  (select distinct agent_id,agent_name from apps.po_agents_v ) ppf2,   
  po.po_req_distributions_all prd,   
  inv.mtl_system_items_b msi,   
  po.po_line_locations_all pll,   
  po.po_lines_all pl,   
  po.po_headers_all ph   
  WHERE   
  prh.requisition_header_id = prl.requisition_header_id   
  and prl.requisition_line_id = prd.requisition_line_id   
  and ppf1.person_id = prh.preparer_id   
  and prh.creation_date between ppf1.effective_start_date and ppf1.effective_end_date   
  and ppf2.agent_id(+) = msi.buyer_id   
  and msi.inventory_item_id = prl.item_id   
  and msi.organization_id = prl.destination_organization_id   
  and pll.line_location_id(+) = prl.line_location_id   
  and pll.po_header_id = ph.po_header_id(+)   
  AND PLL.PO_LINE_ID = PL.PO_LINE_ID(+)   
  AND PRH.AUTHORIZATION_STATUS = 'APPROVED'   
  AND PLL.LINE_LOCATION_ID IS NULL   
  AND PRL.CLOSED_CODE IS NULL   
  AND NVL(PRL.CANCEL_FLAG,'N') <> 'Y'  
  ORDER BY 1,2  
  
-------------------------------------------------------------------------

7. List all the POs with there approval ,invoice and Payment Details
----- List and PO With there approval , invoice and payment details  
select   
a.org_id "ORG ID",   
E.SEGMENT1 "VENDOR NUM",  
e.vendor_name "SUPPLIER NAME",  
UPPER(e.vendor_type_lookup_code) "VENDOR TYPE",   
f.vendor_site_code "VENDOR SITE CODE",  
f.ADDRESS_LINE1 "ADDRESS",  
f.city "CITY",  
f.country "COUNTRY",   
to_char(trunc(d.CREATION_DATE)) "PO Date",   
d.segment1 "PO NUM",  
d.type_lookup_code "PO Type",   
c.quantity_ordered "QTY ORDERED",   
c.quantity_cancelled "QTY CANCELLED",   
g.item_id "ITEM ID" ,   
g.item_description "ITEM DESCRIPTION",  
g.unit_price "UNIT PRICE",   
(NVL(c.quantity_ordered,0)-NVL(c.quantity_cancelled,0))*NVL(g.unit_price,0) "PO Line Amount",   
(select   
decode(ph.approved_FLAG, 'Y', 'Approved')   
from po.po_headers_all ph   
where ph.po_header_ID = d.po_header_id)"PO Approved?",   
a.invoice_type_lookup_code "INVOICE TYPE",  
a.invoice_amount "INVOICE AMOUNT",   
to_char(trunc(a.INVOICE_DATE)) "INVOICE DATE",   
a.invoice_num "INVOICE NUMBER",   
(select   
decode(x.MATCH_STATUS_FLAG, 'A', 'Approved')   
from ap.ap_invoice_distributions_all x   
where x.INVOICE_DISTRIBUTION_ID = b.invoice_distribution_id)"Invoice Approved?",   
a.amount_paid,  
h.amount,   
h.check_id,   
h.invoice_payment_id "Payment Id",   
i.check_number "Cheque Number",   
to_char(trunc(i.check_DATE)) "PAYMENT DATE"   
FROM AP.AP_INVOICES_ALL A,   
AP.AP_INVOICE_DISTRIBUTIONS_ALL B,   
PO.PO_DISTRIBUTIONS_ALL C,   
PO.PO_HEADERS_ALL D,   
PO.PO_VENDORS E,   
PO.PO_VENDOR_SITES_ALL F,   
PO.PO_LINES_ALL G,   
AP.AP_INVOICE_PAYMENTS_ALL H,   
AP.AP_CHECKS_ALL I   
where a.invoice_id = b.invoice_id   
and b.po_distribution_id = c. po_distribution_id (+)   
and c.po_header_id = d.po_header_id (+)   
and e.vendor_id (+) = d.VENDOR_ID   
and f.vendor_site_id (+) = d.vendor_site_id   
and d.po_header_id = g.po_header_id   
and c.po_line_id = g.po_line_id   
and a.invoice_id = h.invoice_id   
and h.check_id = i.check_id   
and f.vendor_site_id = i.vendor_site_id   
and c.PO_HEADER_ID is not null   
and a.payment_status_flag = 'Y'   
and d.type_lookup_code != 'BLANKET'   
 

 ------------------------------------------------------------------------
 
8.You need to know the link to GL_JE_LINES table for purchasing accrual and budgetary control actions..
The budgetary (encumbrance) and accrual actions in the purchasing module generate records that will be imported into GL for the corresponding accrual and budgetary journals.
The following reference fields are used to capture and keep PO information in the GL_JE_LINES table.
These reference fields are populated when the Journal source (JE_SOURCE in GL_JE_HEADERS) is
Purchasing.
Budgetary Records from PO (These include reservations, reversals and cancellations):
REFERENCE_1- Source (PO or REQ)
REFERENCE_2- PO Header ID or Requisition Header ID (from po_headers_all.po_header_id or
po_requisition_headers_all.requisition_header_id)
REFERENCE_3- Distribution ID (from po_distributions_all.po_distribution_id or
po_req_distributions_all.distribution_id)
REFERENCE_4- Purchase Order or Requisition number (from po_headers_all.segment1 or
po_requisition_headers_all.segment1)
REFERENCE_5- (Autocreated Purchase Orders only) Backing requisition number (from po_requisition_headers_all.segment1)
Accrual Records from PO:
REFERENCE_1- Source (PO)
REFERENCE_2- PO Header ID (from po_headers_all.po_header_id)
REFERENCE_3- Distribution ID (from po_distributions_all.po_distribution_id
REFERENCE_4- Purchase Order number (from po_headers_all.segment1)
REFERENCE_5- (ON LINE ACCRUALS ONLY) Receiving Transaction ID (from rcv_receiving_sub_ledger.rcv_transaction_id)
Take a note for Period end accruals, the REFERENCE_5 column is not used.
 
------------------------------------------------------------------------

9. List me all open PO's
----- List all open PO'S  
select   
h.segment1 "PO NUM",   
h.authorization_status "STATUS",   
l.line_num "SEQ NUM",   
ll.line_location_id,   
d.po_distribution_id ,   
h.type_lookup_code "TYPE"   
from   
po.po_headers_all h,   
po.po_lines_all l,   
po.po_line_locations_all ll,   
po.po_distributions_all d   
where h.po_header_id = l.po_header_id   
and ll.po_line_id = l.po_Line_id   
and ll.line_location_id = d.line_location_id   
and h.closed_date is null   
and h.type_lookup_code not in ('QUOTATION')  



link: http://www.oracleappsquery.com/?q=oracle-apps-r12-PO-Purchasing-useful-sql-scripts-queries