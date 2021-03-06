package com.abstratt.mdd.target.tests.jee

import com.abstratt.mdd.core.tests.harness.AssertHelper
import com.abstratt.mdd.target.jee.QueryActionGenerator
import com.abstratt.mdd.target.tests.AbstractGeneratorTest
import java.io.IOException
import org.eclipse.core.runtime.CoreException
import org.eclipse.uml2.uml.Operation

import static extension com.abstratt.mdd.core.util.ActivityUtils.*

class QueryActionGeneratorTests extends AbstractGeneratorTest {
    new(String name) {
        super(name)
    }

    def void testExtent() throws CoreException, IOException {
        var source = '''
            model crm;
            class Customer
                attribute name : String;  
                query findAll() : Customer[*];
                begin
                    return Customer extent;
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::findAll')

        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq.distinct(true)
            ''', generated.toString)
    }

    def void testSelectByBooleanValue() throws CoreException, IOException {
        var source = '''
            model crm;
            class Customer
                attribute name : String;
                attribute vip : Boolean;              
                query findVip() : Customer[*];
                begin
                    return Customer extent.select((c : Customer) : Boolean {
                        c.vip
                    });
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::findVip')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq.distinct(true)
                    .where(cb.isTrue(customer_.get("vip")))
            ''', generated.toString)
    }
    
    def void testExists() throws CoreException, IOException {
        var source = '''
            model crm;
            class Company
                attribute name : String;
                attribute customers : Customer[*];              
                static query companiesWithVipCustomers() : Company[*];
                begin
                    return Company extent.select((company : Company) : Boolean {
                        company.customers.exists((customer : Customer) : Boolean {
                            customer.vip
                        })
                    });
                end;
            end;
            class Customer
                attribute name : String;
                attribute vip : Boolean;              
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Company::companiesWithVipCustomers')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        // we want to issue the exists function the same way for whichever case we are handling here
        // so we will always add a criteria for relating the child object to the parent object
        // (I don't really know what I am saying here)  
        AssertHelper.assertStringsEqual(
            '''
                cq.distinct(true)
                    .where(cb.exists(
                        customerSubquery
                            .select(customer_)
                            .where(
                                cb.equal(customer_.get("company"), company_), 
                                cb.isTrue(customer_.get("vip"))
                            )
                    ))
                            
            ''', generated.toString)
    }
    
    
    def void testSelectByAttributeInRelatedEntity() throws CoreException, IOException {
        var source = '''
            model crm;
            class Company
                attribute revenue : Double;
            end;
            class Customer
                attribute name : String;
                attribute company : Company;              
                query findByCompanyRevenue(threshold : Double) : Customer[*];
                begin
                    return Customer extent.select((c : Customer) : Boolean {
                        c.company.revenue >= threshold
                    });
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::findByCompanyRevenue')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq
                    .distinct(true)
                    .where(cb.greaterThanOrEqualTo(
                        company_.get("revenue"),
                        cb.parameter(Double.class,"threshold")
                    ))
            ''', generated.toString)
    }

    def void testCollectAttributes() throws CoreException, IOException {
        var source = '''
            model crm;
            class Company
                attribute revenue : Double;
            end;            
            class Customer
                attribute name : String;
                attribute company : Company;                              
                query getCompanyRevenueWithCustomerName() : { customerName : String, companyRevenue : Double}[*];
                begin
                    return Customer extent.collect((c : Customer) : { : String, : Double} {
                        { cName := c.name, cRevenue := c.company.revenue }
                    });
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::getCompanyRevenueWithCustomerName')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq
                    .distinct(true)
                    .multiselect(customer_.get("name"), customer_.get("company").get("revenue"))
            ''', generated.toString)
    }


    def void testSelectByRelatedEntity() throws CoreException, IOException {
        var source = '''
            model crm;
            class Company
                attribute revenue : Double;
            end;
            class Customer
                attribute name : String;
                attribute company : Company;              
                query findByCompany(toMatch : Company) : Customer[*];
                begin
                    return Customer extent.select((c : Customer) : Boolean {
                        c.company == toMatch
                    });
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::findByCompany')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq.distinct(true)
                    .where(cb.equal(
                        customer_.get("company"),
                        cb.parameter(Company.class,"toMatch")
                    ))
            ''', generated.toString)
    }


    def void testSelectByDoubleComparison() throws CoreException, IOException {
        var source = '''
            model crm;
            class Customer
                attribute name : String;
                attribute vip : Boolean;
                attribute salary : Double;
                query findHighestGrossing(threshold : Double) : Customer[*];
                begin
                    return Customer extent.select((c : Customer) : Boolean {
                        c.salary >= threshold
                    });
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::findHighestGrossing')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq
                    .distinct(true)
                    .where(cb.greaterThanOrEqualTo(
                        customer_.get("salary"),
                        cb.parameter(Double.class,"threshold")
                    ))
            ''', generated.toString)
    }

    def void testGroupByAttributeIntoCountWithFilter() throws CoreException, IOException {
        var source = '''
            model crm;
            class Customer
                attribute name : String;
                attribute title : String;              
                query countByTitle() : {title : String, customerCount : Integer} [*];
                begin
                    return Customer extent.groupBy((c : Customer) : String {
                        c.title
                    }).groupCollect((group : Customer[*]) : {title:String, customerCount : Integer} {
                        { 
                            title := group.one().title,
                            customerCount := group.size()
                        }   
                    }).select((counted : {title:String, customerCount : Integer}) : Boolean {
                        counted.customerCount > 100
                    });
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::countByTitle')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq
                    .groupBy(customer_.get("title"))
                    .multiselect(customer_.get("title"), cb.count(customer_))
                    .having(cb.greaterThan(cb.count(customer_), cb.literal(100)))
            ''', generated.toString)
    }
    
    def void testGroupByAttributeIntoCount() throws CoreException, IOException {
        var source = '''
            model crm;
            class Customer
                attribute name : String;
                attribute title : String;              
                query countByTitle() : {title : String, customerCount : Integer} [*];
                begin
                    return Customer extent.groupBy((c : Customer) : String {
                        c.title
                    }).groupCollect((group : Customer[*]) : {title:String, customerCount : Integer} {
                        { 
                            title := group.one().title,
                            customerCount := group.size()
                        }   
                    });
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::countByTitle')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq
                    .groupBy(customer_.get("title"))
                    .multiselect(customer_.get("title"), cb.count(customer_))
            ''', generated.toString)
    }
    

    def void testGroupByAttributeIntoSum() throws CoreException, IOException {
        var source = '''
            model crm;
            class Customer
                attribute name : String;
                attribute title : String;
                attribute salary : Double;              
                query sumSalaryByTitle() : {title : String, totalSalary : Double} [*];
                begin
                    return Customer extent.groupBy((c : Customer) : String {
                        c.title
                    }).groupCollect((grouped : Customer[*]) : {title : String, totalSalary : Double} {
                        { 
                            title := grouped.one().title,
                            totalSalary := grouped.sum((c : Customer) : Double {
                                c.salary
                            })
                        }   
                    });
                end;
            end;
            end.
        '''
        parseAndCheck(source)
        val op = getOperation('crm::Customer::sumSalaryByTitle')
        val root = getStatementSourceAction(op)
        val generated = new QueryActionGenerator(repository).generateAction(root)
        AssertHelper.assertStringsEqual(
            '''
                cq
                    .groupBy(customer_.get("title"))
                    .multiselect(customer_.get("title"), cb.sum(customer_.get("salary")))
            ''', generated.toString)
    }
    
    def getStatementSourceAction(Operation op) {
        op.activity.rootAction.findStatements.last.sourceAction
    }

}
